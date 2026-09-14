# frozen_string_literal: true

class Fetch
  def initialize(client: nil)
    @client = client
    @stats_mutex = Mutex.new
    @stats = {
      processed: 0,
      updated: 0,
      request_failures: 0,
      process_failures: 0,
      failed_codes: []
    }
  end

  # 批量执行（按 purpose 过滤）
  def fetch_all(purpose: nil, concurrency: default_concurrency)
    lock_name = "fetch:all:#{purpose || 'all'}"
    locked = Lock.with_lock(lock_name, ttl: 30.minutes) do
      scope = Article.where.not(code: [nil, ""])
      scope = scope.where(purpose: Article.purposes.fetch(purpose.to_s)) if purpose
      codes = scope.pluck(:code)

      if concurrency > 1
        puts "[Fetch] 启用并行处理，线程数=#{concurrency}"
        fetch_codes_in_parallel(codes, concurrency)
      else
        codes.each do |code|
          json = request(code)
          next unless json

          article = Article.find_by(code: code)
          process_article(article, json) if article
        end
      end

      print_summary
      puts "[Fetch] 批量处理完成 (purpose=#{purpose || 'all'})"
    end
    return if locked

    puts "[Fetch] 跳过执行：已有抓取任务正在运行 (lock=#{lock_name})"
  end

  def fetch_policies
    fetch_all(purpose: :policy)
  end

  def fetch_interpretations
    fetch_all(purpose: :interpretation)
  end

  def fetch_article(code, purpose: nil)
    article = find_article(code, purpose: purpose)
    return puts("[Fetch] 未找到 Article(code=#{code}, purpose=#{purpose || 'all'})") unless article

    json = request(code)
    return puts("[Fetch] 获取 JSON 失败 (article #{code})") unless json

    process_article(article, json)
  end

  private

  def config
    Loader.current
  end

  def fetch_url
    config.dig("source", "fetch_url")
  end

  def default_concurrency
    [config.dig("sync", "fetch_concurrency").to_i, 1].max
  end

  def client
    @client || (Thread.current[:fetch_client] ||= Client.new(
      url: fetch_url,
      headers: { "Content-Type" => "application/x-www-form-urlencoded; charset=UTF-8" }
    ))
  end

  def find_article(code, purpose:)
    scope = Article.where(code: code)
    scope = scope.where(purpose: Article.purposes.fetch(purpose.to_s)) if purpose
    scope.first
  end

  def request(code)
    client.post(body: "id=#{code}")
  rescue => e
    puts "[Fetch] 请求失败 code=#{code}: #{Mapper.compact_message(e)}"
    with_stats_lock do
      @stats[:request_failures] += 1
      @stats[:failed_codes] << code
    end
    nil
  end

  # 多线程只发 HTTP 请求,写库统一收敛回主线程串行执行,
  # 避免 SQLite 并发写入报 "database is locked"。
  def fetch_codes_in_parallel(codes, concurrency)
    Runner.run(
      codes,
      concurrency,
      worker: lambda do |code|
        json = request(code)
        Thread.current[:fetch_client] = nil
        [code, json]
      end,
      consumer: lambda do |(code, json)|
        return unless json

        article = Article.find_by(code: code)
        return unless article

        begin
          process_article(article, json)
        rescue => e
          with_stats_lock do
            @stats[:process_failures] += 1
            @stats[:failed_codes] << code
          end
          puts "[Fetch] 处理失败 code=#{code}: #{Mapper.compact_message(e)}"
        end
      end
    )
  end

  def extract_data(json)
    root = json["results"]
    return puts "[Fetch] JSON 中无 results" unless root.is_a?(Hash)

    data = root.dig("data", "results")
    return puts "[Fetch] JSON 中无 data.results" unless data.is_a?(Array)

    data
  end

  def process_article(article, json)
    data = extract_data(json)
    return unless data

    with_stats_lock { @stats[:processed] += 1 }

    fill_published_at(article, data)
    update_content(article, data)

    return unless article.policy?

    link_related_articles(article, data)
    link_interpretation(article, data)
  end

  def fill_published_at(record, data)
    return if record.published_at.present?

    time_str = data.dig(0, "publishedTimeStr")
    return if time_str.blank?

    record.update(published_at: Clock.parse(time_str))
    puts "[Fetch] #{record.class}(#{record.code}) published_at 已更新为 #{time_str}"
  end

  def update_content(article, data)
    item = data.find { |row| row["contentHtml"].present? }
    return puts "[Fetch] 未找到正文内容 (#{article.code})" unless item

    cleaned = Sanitizer.clean(item["contentHtml"])
    if cleaned != article.content
      article.update!(content: cleaned)
      article.mark_dirty! # 内容变了,下次 publish 要重新推送
      with_stats_lock { @stats[:updated] += 1 }
      puts "[Fetch] #{article.purpose}(#{article.code}) 内容已更新"
    end
  end

  # 处理关联政策
  def link_related_articles(policy, data)
    container = data.find { |item| item["policyDocument"].present? }
    return puts "[Fetch] 未找到 policyDocument" unless container

    ids = container["policyDocument"].map { |item| item["id"].to_s }.reject(&:blank?).uniq
    related_by_code = Article.where(code: ids).index_by(&:code)

    container["policyDocument"].each do |item|
      related = related_by_code[item["id"].to_s]
      next unless related
      next if policy.related_articles.exists?(related.id)

      policy.related_articles << related
      puts "[Fetch] policy(#{policy.code}) 关联了政策 #{related.code}"
    end
  end

  # 关联 Interpretation（一对一）
  def link_interpretation(policy, data)
    container = data.find { |item| item["policyInterpretation"].present? }
    return puts "[Fetch] 未找到 policyInterpretation" unless container

    interpretation_data = container["policyInterpretation"]&.first
    return puts "[Fetch] Policy(#{policy.code}) 无 Interpretation" unless interpretation_data

    interpretation = Article.find_by(code: interpretation_data["id"], purpose: Article.purposes["interpretation"])
    return puts "[Fetch] Interpretation 未找到 id=#{interpretation_data['id']}" unless interpretation
    return if policy.child_article == interpretation

    policy.update!(child_article: interpretation)
    puts "[Fetch] Policy(#{policy.code}) ⇆ Interpretation(#{interpretation.code}) 已建立关联"
  end

  def with_stats_lock(&block)
    @stats_mutex.synchronize(&block)
  end

  def print_summary
    puts "[Fetch][Summary] processed=#{@stats[:processed]} updated=#{@stats[:updated]} " \
         "request_failures=#{@stats[:request_failures]} process_failures=#{@stats[:process_failures]}"
    return unless @stats[:failed_codes].any?

    sample = @stats[:failed_codes].compact.uniq.first(30)
    puts "[Fetch][Summary] failed_codes(sample<=30): #{sample.join(', ')}"
  end
end

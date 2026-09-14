# frozen_string_literal: true

class Fetch
  def initialize(client: nil)
    @client = client
    @stats_mutex = Mutex.new
    @stats = {
      processed: 0,
      updated: 0,
      skipped: 0,
      request_failures: 0,
      process_failures: 0,
      failed_codes: []
    }
  end

  # 批量执行（按 purpose 过滤,内部用 category 判断解读）
  def fetch_all(purpose: nil, concurrency: default_concurrency)
    lock_name = "fetch:all:#{purpose || 'all'}"
    locked = Lock.with_lock(lock_name, ttl: 30.minutes) do
      scope = Article.where.not(code: [nil, ""])
      scope = filter_by_purpose(scope, purpose)
      codes = scope.pluck(:code)

      if codes.empty?
        puts "[Fetch] 数据库没有可抓取的记录。"
        puts "[Fetch] 若是清空库后重建,请先运行 rake search(或直接 rake rebuild),"
        puts "[Fetch] 先重建 article 列表,再抓取详情正文。"
        return
      end

      total = codes.size
      puts "[Fetch] 共 #{total} 条待抓取"
      if concurrency > 1
        puts "[Fetch] 启用并行处理，线程数=#{concurrency}"
        fetch_codes_in_parallel(codes, concurrency)
      else
        codes.each_with_index do |code, index|
          json = request(code)
          if json.nil?
            with_stats_lock { @stats[:skipped] += 1 }
          else
            article = Article.find_by(code: code)
            process_article(article, json) if article
          end
          report_progress(index + 1, total)
        end
      end

      Progress.done("[Fetch] 抓取完成 #{total} 条")
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

  # 反向补抓:从政策详情的 policyInterpretation 收集解读 id,补抓未入库的解读
  # (图片政策解读、视频政策解读等不在 search 列表里的解读)。
  def fetch_missing_interpretations
    puts "[Fetch] 开始反向补抓解读..."
    referenced = collect_referenced_interpretation_ids
    existing = Article.where.not(code: [nil, ""]).pluck(:code).to_set
    # 未入库的解读 + 已入库但 category 为空的解读(之前 level 4 分类缺失导致)
    category_missing = Article.where(category_id: nil).pluck(:code)
    missing = ((referenced - existing) + category_missing).uniq.sort

    puts "[Fetch] 政策引用的解读 #{referenced.size} 个,已入库 #{referenced.size - (missing & referenced.to_a).size} 个,待处理 #{missing.size} 个"

    if missing.empty?
      puts "[Fetch] 没有需要补抓的解读"
      print_summary
      return
    end

    missing.each_with_index do |code, index|
      json = request(code)
      if json.nil?
        with_stats_lock { @stats[:skipped] += 1 }
      else
        begin
          upsert_missing_interpretation(json)
          with_stats_lock { @stats[:processed] += 1 }
        rescue => e
          with_stats_lock do
            @stats[:process_failures] += 1
            @stats[:failed_codes] << code
          end
          puts "[Fetch] 解读处理失败 code=#{code}: #{Mapper.compact_message(e)}"
        end
      end
      report_progress(index + 1, missing.size)
    end

    Progress.done("[Fetch] 反向补抓完成 #{missing.size} 个解读")
    print_summary
  end

  def fetch_article(code, purpose: nil)
    article = find_article(code)
    return puts("[Fetch] 未找到 Article(code=#{code})") unless article

    json = request(code)
    return puts("[Fetch] 获取 JSON 失败 (article #{code})") unless json

    before_content = article.content
    process_article(article, json)

    if article.content.present? && article.content != before_content
      puts "[Fetch] #{article.category&.title}(#{article.code}) 完成,正文已更新"
    else
      puts "[Fetch] #{article.category&.title}(#{article.code}) 完成,内容无变化"
    end
  end

  private

  # 遍历所有政策文章的详情,收集 policyInterpretation 引用的全部解读 id
  def collect_referenced_interpretation_ids
    ids = Set.new
    policy_codes = Article.policy.where.not(code: [nil, ""]).pluck(:code)
    total = policy_codes.size
    puts "[Fetch] 遍历 #{total} 篇政策详情,收集解读引用..."

    policy_codes.each_with_index do |code, index|
      json = request(code)
      if json
        data = extract_data(json)
        if data
          container = data.find { |row| row["policyInterpretation"].present? }
          if container
            container["policyInterpretation"].each do |item|
              ids << item["id"].to_s if item["id"].present?
            end
          end
        end
      end

      done = index + 1
      Progress.refresh("[Fetch] 收集引用 #{done}/#{total} (#{(done * 100.0 / total).round(1)}%)")
    end

    Progress.done("[Fetch] 引用收集完成:遍历 #{total} 篇,发现 #{ids.size} 个解读引用")
    ids
  end

  # 解析一条解读详情,创建/更新 Article,并按 channel 设置分类、按 policyDocument 关联政策
  # content 若有值则写入(图片/视频解读为 img/video 标签)
  def upsert_missing_interpretation(json)
    data = extract_data(json)
    return unless data

    item = data.find { |row| row["contentHtml"].present? } || data.first
    return unless item

    code = item["mId"].to_s
    return if code.blank?

    article = Article.find_or_initialize_by(code: code)
    article.origin_url = normalize_url(item["url"])
    article.title = Sanitizer.clean(item["title"])
    article.published_at = Clock.parse(item["publishedTimeStr"]) if item["publishedTimeStr"].present?
    article.category = find_category_by_channel(item["channel"])
    article.content = Sanitizer.clean_html(item["contentHtml"]) if item["contentHtml"].present?
    article.save!

    link_policy_from_interpretation(article, data)

    article
  end

  # 从解读详情的 policyDocument 找到政策,建立 policy 关联
  def link_policy_from_interpretation(interpretation, data)
    container = data.find { |row| row["policyDocument"].present? }
    return unless container

    policy_doc = container["policyDocument"]&.first
    return unless policy_doc

    policy = Article.find_by(code: policy_doc["id"].to_s)
    return unless policy
    return if interpretation.policy == policy

    interpretation.update!(policy: policy)
    puts "[Fetch] Interpretation(#{interpretation.code}) 关联政策 #{policy.code}" if ENV["DEBUG"]
  end

  # 取 channel 最后一层(最细分类)的 displayName 作为 category
  def find_category_by_channel(channel)
    return nil unless channel.is_a?(Array) && channel.any?

    leaf = channel.last
    title = leaf["displayName"].presence || leaf["channelName"]
    return nil if title.blank?

    Category.find_by(title: title)
  end

  def normalize_url(url)
    Sanitizer.normalize_url(url)
  end

  def filter_by_purpose(scope, purpose)
    return scope unless purpose

    case purpose.to_sym
    when :policy then scope.where.not(category_id: Category.interpretation_ids)
    when :interpretation then scope.where(category_id: Category.interpretation_ids)
    else scope
    end
  end

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

  def find_article(code)
    Article.where(code: code).first
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
    total = codes.size
    done = 0
    Runner.run(
      codes,
      concurrency,
      worker: lambda do |code|
        json = request(code)
        Thread.current[:fetch_client] = nil
        [code, json]
      end,
      consumer: lambda do |(code, json)|
        done += 1
        if json
          article = Article.find_by(code: code)
          if article
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
        else
          with_stats_lock { @stats[:skipped] += 1 }
        end
        report_progress(done, total)
      end
    )
  end

  # 单行刷新进度条(每条都刷,\r 覆盖不滚屏),并实时显示成功/失败/跳过数
  def report_progress(done, total)
    pct = (done * 100.0 / total).round(1)
    stats = with_stats_lock { @stats.dup }
    fails = stats[:request_failures] + stats[:process_failures]
    Progress.refresh(
      "[Fetch] #{done}/#{total} (#{pct}%) 成功:#{stats[:processed]} " \
      "失败:#{fails} 跳过:#{stats[:skipped]}"
    )
  end

  def extract_data(json)
    root = json["results"]
    unless root.is_a?(Hash)
      puts "[Fetch] JSON 中无 results" if ENV["DEBUG"]
      return nil
    end

    data = root.dig("data", "results")
    unless data.is_a?(Array)
      puts "[Fetch] JSON 中无 data.results" if ENV["DEBUG"]
      return nil
    end

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
    puts "[Fetch] #{record.class}(#{record.code}) published_at 已更新为 #{time_str}" if ENV["DEBUG"]
  end

  def update_content(article, data)
    item = data.find { |row| row["contentHtml"].present? }
    unless item
      puts "[Fetch] 未找到正文内容 (#{article.code})" if ENV["DEBUG"]
      return
    end

    cleaned = Sanitizer.clean_html(item["contentHtml"])
    if cleaned != article.content
      article.update!(content: cleaned)
      article.mark_dirty! # 内容变了,下次 publish 要重新推送
      with_stats_lock { @stats[:updated] += 1 }
      puts "[Fetch] #{article.category&.title}(#{article.code}) 内容已更新" if ENV["DEBUG"]
    end
  end

  # 处理关联政策
  def link_related_articles(policy, data)
    container = data.find { |item| item["policyDocument"].present? }
    unless container
      puts "[Fetch] 未找到 policyDocument" if ENV["DEBUG"]
      return
    end

    ids = container["policyDocument"].map { |item| item["id"].to_s }.reject(&:blank?).uniq
    related_by_code = Article.where(code: ids).index_by(&:code)

    container["policyDocument"].each do |item|
      related = related_by_code[item["id"].to_s]
      next unless related
      next if policy.related_articles.exists?(related.id)

      policy.related_articles << related
      puts "[Fetch] policy(#{policy.code}) 关联了政策 #{related.code}" if ENV["DEBUG"]
    end
  end

  # 关联 Interpretation:每个解读都要挂回它的政策(policy),
  # 一个政策可能有多篇解读,所以遍历全部。
  def link_interpretation(policy, data)
    container = data.find { |item| item["policyInterpretation"].present? }
    unless container
      puts "[Fetch] 未找到 policyInterpretation" if ENV["DEBUG"]
      return
    end

    interpretations = container["policyInterpretation"]
    return if interpretations.blank?

    interpretations.each do |interpretation_data|
      interpretation = Article.find_by(code: interpretation_data["id"].to_s)
      unless interpretation
        puts "[Fetch] Interpretation 未找到 id=#{interpretation_data['id']}" if ENV["DEBUG"]
        next
      end
      next if interpretation.policy == policy

      interpretation.update!(policy: policy)
      puts "[Fetch] Policy(#{policy.code}) ⇆ Interpretation(#{interpretation.code}) 已建立关联" if ENV["DEBUG"]
    end
  end

  def with_stats_lock(&block)
    @stats_mutex.synchronize(&block)
  end

  def print_summary
    puts "[Fetch][Summary] processed=#{@stats[:processed]} updated=#{@stats[:updated]} " \
         "skipped=#{@stats[:skipped]} request_failures=#{@stats[:request_failures]} " \
         "process_failures=#{@stats[:process_failures]}"
    return unless @stats[:failed_codes].any?

    sample = @stats[:failed_codes].compact.uniq.first(30)
    puts "[Fetch][Summary] failed_codes(sample<=30): #{sample.join(', ')}"
  end
end

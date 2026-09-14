# frozen_string_literal: true

require "digest"
require "set"

class Search
  INTERPRETATION_LABEL = "文字政策解读"

  def initialize(client: nil)
    @client = client
    preload_reference_cache
    @article_topic_ids = {}
    @article_tax_ids = {}
    @article_attachment_urls = {}
    @stats_mutex = Mutex.new
    @stats = {
      pages: 0,
      records_seen: 0,
      records_saved: 0,
      skipped_existing: 0,
      errors: 0,
      failed_pages: []
    }
  end

  # 全量抓取
  def search_all(concurrency: default_concurrency)
    lock_name = "search:all"
    locked = Lock.with_lock(lock_name, ttl: 30.minutes) do
      puts "[Search] 开始获取总页数 ..."
      first_json = request_page

      total = first_json.dig("searchResultAll", "total").to_i
      raise "[Search] API 未返回 total 字段" if total.zero?

      total_pages = (total / 10.0).ceil
      puts "[Search] 共 #{total} 条数据，#{total_pages} 页"

      # 先抓后面的老页(1..total_pages-1),最后再写第 0 页(最新)。
      # 这样最新文章最后入库、拿到最大的自增 id,保证 id 越大越新。
      pages = (1...total_pages).to_a
      if concurrency > 1
        puts "[Search] 启用并行抓取，线程数=#{concurrency}"
        parallel_request_pages(pages, concurrency) do |page, json|
          process_page(json, stop_on_existing: false)
          with_stats_lock { @stats[:pages] += 1 }
          report_page_progress(total_pages)
        end
      else
        pages.each do |page|
          json = request_page(page)
          process_page(json, stop_on_existing: false)
          with_stats_lock { @stats[:pages] += 1 }
          report_page_progress(total_pages)
        end
      end

      # 最后处理第 0 页(最新)
      process_page(first_json, stop_on_existing: false)
      with_stats_lock { @stats[:pages] += 1 }
      report_page_progress(total_pages)

      Progress.done("[Search] 页面抓取完成 #{total_pages} 页")
      print_summary
      puts "[Search] 全量抓取完成"
    end
    return if locked

    puts "[Search] 跳过执行：已有任务正在运行 (lock=#{lock_name})"
  end

  # 增量抓取:按最后更新时间倒序拉,遇到已存在且内容未变的记录即停止
  def search_incremental
    lock_name = "search:incremental"
    locked = Lock.with_lock(lock_name, ttl: 20.minutes) do
      puts "[Search] 开始增量抓取..."
      page = 0

      loop do
        json = request_page(page)
        list = extract_list(json)
        break if list.empty?

        with_stats_lock { @stats[:pages] += 1 }
        break if process_page(json, stop_on_existing: true)

        page += 1
      end

      print_summary
      puts "[Search] 增量抓取完成"
    end
    return if locked

    puts "[Search] 跳过执行：已有增量任务正在运行 (lock=#{lock_name})"
  end

  private

  def config
    Loader.current
  end

  def search_url
    config.dig("source", "search_url")
  end

  def default_concurrency
    [config.dig("sync", "search_concurrency").to_i, 1].max
  end

  def client
    @client || (Thread.current[:search_client] ||= Client.new(url: search_url))
  end

  def request_page(page = 0)
    json = client.get(
      siteCode: "bm29000002",
      searchWord: "",
      type: "",
      pageSize: 10,
      pageNum: page,
      orderBy: 5,
      column: "政策法规,政策解读,政策指引",
      label: "文字政策解读,法律,行政法规,国务院文件,税务部门规章,税务规范性文件,财税文件,其他文件,工作通知,政策指引",
      likeDoc: "0",
      wordPlace: "0",
      indexCode: "1",
      participleRule: "5",
      cwrqStart: "null",
      cwrqEnd: "null",
      searchSiteName: "GSFFK"
    )
    json || {}
  rescue => e
      error_message = Mapper.compact_message(e)
    puts "[Search] 请求失败 page=#{page}: #{error_message}"
    with_stats_lock do
      @stats[:errors] += 1
      @stats[:failed_pages] << page
    end
    {}
  end

  # 多线程只做 HTTP 请求,结果收敛回主线程串行写库(避免 SQLite 并发写)
  def parallel_request_pages(pages, concurrency)
    Runner.run(
      pages,
      concurrency,
      worker: lambda do |page|
        json = request_page(page)
        Thread.current[:search_client] = nil
        [page, json]
      end,
      consumer: ->((page, json)) { yield(page, json) }
    )
  end

  def extract_list(json)
    json.dig("searchResultAll", "searchTotal") || []
  end

  # 处理每一页，stop_on_existing=true 时遇到已存在且内容无变化的记录后终止并返回 true
  def process_page(json, stop_on_existing:)
    list = extract_list(json)
    indexed = build_existing_index(list)

    list.each do |item|
      with_stats_lock { @stats[:records_seen] += 1 }
      purpose = purpose_from_item(item)
      key = article_key(item)
      existing_record = indexed.dig(purpose, :records, key)
      existing = indexed.dig(purpose, :keys)&.include?(key)

      if stop_on_existing && existing && !content_changed?(existing_record, item)
        with_stats_lock { @stats[:skipped_existing] += 1 }
        return true
      end

      article = existing_record || initialize_article(item, purpose)
      upsert_article(item, purpose, article)
      with_stats_lock { @stats[:records_saved] += 1 }

      indexed[purpose][:keys] << key
      indexed[purpose][:records][key] = article
    rescue => e
      with_stats_lock { @stats[:errors] += 1 }
      puts "[Search] 处理失败 item_id=#{item['id']}: #{Mapper.compact_message(e)}"
    end

    false
  end

  def content_changed?(article, item)
    article.content_hash != compute_hash(item)
  end

  # 单行刷新页进度,并实时显示失败页数
  def report_page_progress(total_pages)
    done = @stats[:pages]
    pct = (done * 100.0 / total_pages).round(1)
    failed = with_stats_lock { @stats[:failed_pages].size }
    Progress.refresh("[Search] #{done}/#{total_pages} 页 (#{pct}%) 失败页:#{failed}")
  end

  def print_summary
    puts "[Search][Summary] pages=#{@stats[:pages]} seen=#{@stats[:records_seen]} " \
         "saved=#{@stats[:records_saved]} skipped=#{@stats[:skipped_existing]} errors=#{@stats[:errors]}"
    return unless @stats[:failed_pages].any?

    pages = @stats[:failed_pages].uniq.sort.first(20)
    puts "[Search][Summary] failed_pages(sample<=20): #{pages.join(', ')}"
  end

  def with_stats_lock(&block)
    @stats_mutex.synchronize(&block)
  end

  def purpose_from_item(item)
    item["label"] == INTERPRETATION_LABEL ? :interpretation : :policy
  end

  def purpose_value(purpose)
    Article.purposes.fetch(purpose.to_s)
  end

  def normalize_url(url)
    url.to_s.strip.gsub(/^http:/, "https:")
  end

  def extract_code(item)
    item["id"].to_s.split("_").first
  end

  def article_key(item)
    code = extract_code(item)
    code.present? ? "code:#{code}" : "url:#{normalize_url(item['url'])}"
  end

  def build_existing_index(list)
    grouped = list.group_by { |item| purpose_from_item(item) }
    result = {}

    grouped.each do |purpose, items|
      codes = items.map { |item| extract_code(item) }.reject(&:blank?).uniq
      urls = items.map { |item| normalize_url(item["url"]) }.reject(&:blank?).uniq
      pv = purpose_value(purpose)
      scope = Article.where(purpose: pv)
      records =
        if codes.any? && urls.any?
          scope.where(code: codes).or(scope.where(origin_url: urls)).to_a
        elsif codes.any?
          scope.where(code: codes).to_a
        elsif urls.any?
          scope.where(origin_url: urls).to_a
        else
          []
        end
      keys = Set.new
      record_map = {}

      records.each do |record|
        if record.code.present?
          code_key = "code:#{record.code}"
          keys << code_key
          record_map[code_key] = record
        end

        next unless record.origin_url.present?

        url_key = "url:#{normalize_url(record.origin_url)}"
        keys << url_key
        record_map[url_key] = record
      end

      result[purpose] = { keys: keys, records: record_map }
    end

    result
  end

  def initialize_article(item, purpose)
    code = extract_code(item)
    origin_url = normalize_url(item["url"])
    pv = purpose_value(purpose)
    Article.new(code: code, origin_url: origin_url, purpose: pv)
  end

  def upsert_article(item, purpose, article)
    article.assign_attributes(common_attributes(item, purpose))
    article.assign_attributes(policy_attributes(item)) if purpose == :policy
    article.aging_id ||= @default_aging_id if purpose == :interpretation

    new_hash = compute_hash(item)
    content_changed = article.content_hash != new_hash
    article.content_hash = new_hash
    # 内容有变化(或是新记录)就把 content_version 归零,
    # 下次 publish 命令会把它当作"待发布"重新推送。
    article.content_version = 0 if content_changed

    article.save!

    if purpose == :policy
      sync_topics(article, item)
      sync_taxes(article, item)
      sync_attachments(article, item)
    end

    puts "[Search] #{purpose.to_s.capitalize} 保存成功: #{article.code || article.origin_url}" \
         "#{content_changed ? ' (内容有变化)' : ''}" if ENV["DEBUG"]
    article
  end

  def compute_hash(item)
    Digest::SHA256.hexdigest("#{item['title']}|#{item['content']}|#{item['shortContent']}")
  end

  def common_attributes(item, purpose)
    attrs = {
      title: Sanitizer.clean(item["title"]),
      content: Sanitizer.clean(item["content"]),
      short_content: Sanitizer.clean(item["shortContent"]),
      publisher: item["pubName"],
      origin_url: normalize_url(item["url"]),
      code: extract_code(item),
      purpose: purpose_value(purpose),
      category_id: lookup_id(@category_ids_by_title, Category, item["label"])
    }

    published_at = Clock.parse(item["cwrq"].presence || item["pubDate"])
    attrs[:published_at] = published_at if published_at.present?
    attrs
  end

  def policy_attributes(item)
    attrs = { notice: Sanitizer.clean(item["xxgk_description"]) }

    doc_type = item.dig("govDoc", "docType")
    doc_year = item.dig("govDoc", "docYear")
    doc_no = item.dig("govDoc", "docNo")
    doc_number = item.dig("govDoc", "docNum")

    attrs[:doc_type] = doc_type if doc_type.present?
    attrs[:doc_year] = doc_year if doc_year.present?
    attrs[:doc_no] = doc_no if doc_no.present?
    attrs[:doc_number] = doc_number if doc_number.present?

    attrs[:aging_id] = lookup_id(@aging_ids_by_title, Aging, item["xxgk_aging"]) || @default_aging_id
    attrs
  end

  def parse_json_array(raw)
    return [] if raw.blank?

    value = JSON.parse(raw.to_s)
    value.is_a?(Array) ? value : []
  rescue JSON::ParserError
    []
  end

  def sync_topics(article, item)
    ids = cached_topic_ids(article)
    parse_json_array(item["xxgk_taxPolicy"]).each do |topic_name|
      next if topic_name.blank?

      topic = lookup_record(@topic_ids_by_title, @topics_by_id, Topic, topic_name.to_s.strip)
      next unless topic
      next unless ids.add?(topic.id)

      article.topics << topic
    end
  end

  def sync_attachments(article, item)
    return unless item["appendix"].is_a?(Array)

    source_urls = cached_attachment_urls(article)

    item["appendix"].each do |attachment|
      title = attachment["appendixName"].to_s.strip
      file_url = normalize_url(attachment["appendixUrl"])

      next if title.blank? || file_url.blank?
      next unless source_urls.add?(file_url)

      article.attachments.create!(
        title: title,
        description: Sanitizer.clean(attachment["appendixContent"]),
        file_type: attachment["appendixType"].to_s.strip,
        source_url: file_url
      )
    rescue ActiveRecord::RecordInvalid => e
      puts "[Search] 附件保存失败: #{e.message}"
    end
  end

  def sync_taxes(article, item)
    parent_policy_type = parse_json_array(item["xxgk_taxPolicy"])
    child_tax_list = parse_json_array(item["xxgk_son_taxPolicy"])
    return unless parent_policy_type.include?("税收政策")

    ids = cached_tax_ids(article)
    child_tax_list.uniq.each do |tax_name|
      next if tax_name.blank?

      tax = lookup_record(@tax_ids_by_title, @taxes_by_id, Tax, tax_name.to_s.strip)
      next unless tax
      next unless ids.add?(tax.id)

      article.taxes << tax
    end
  end

  def preload_reference_cache
    @category_ids_by_title = Category.pluck(:title, :id).to_h
    @aging_ids_by_title = Aging.pluck(:title, :id).to_h
    @topic_ids_by_title = Topic.pluck(:title, :id).to_h
    @tax_ids_by_title = Tax.pluck(:title, :id).to_h
    @topics_by_id = Topic.where(id: @topic_ids_by_title.values).index_by(&:id)
    @taxes_by_id = Tax.where(id: @tax_ids_by_title.values).index_by(&:id)
    @default_aging_id = @aging_ids_by_title["全文有效"]
  end

  def lookup_id(cache, model, title)
    return if title.blank?
    return cache[title] if cache.key?(title)

    cache[title] = model.find_by(title: title)&.id
  end

  def lookup_record(ids_cache, records_by_id, model, title)
    id = lookup_id(ids_cache, model, title)
    return unless id

    records_by_id[id] ||= model.find_by(id: id)
  end

  def cached_topic_ids(article)
    @article_topic_ids[article.id] ||= article.topic_ids.to_set
  end

  def cached_tax_ids(article)
    @article_tax_ids[article.id] ||= article.tax_ids.to_set
  end

  def cached_attachment_urls(article)
    @article_attachment_urls[article.id] ||=
      article.attachments.pluck(:source_url).map { |url| normalize_url(url) }.to_set
  end
end

# frozen_string_literal: true

require "json"

module Publish
  # 把本次 bump 到某个 content_version 的记录,批量 POST 给 Worker 的 /api/publish。
  # 鉴权用 Bearer token(D1_PUSH_TOKEN),推送按 code+purpose upsert,天然幂等——
  # 同一批数据重复推送不会产生副作用,网络失败后可以直接重试整批。
  class D1
    BATCH_SIZE = 50

    def initialize(config: Loader.current)
      @push_url = config.dig("d1", "push_url")
      @push_token = config.dig("d1", "push_token")
      raise "D1 push_url / push_token 未配置,检查 crawler/config/secrets" if @push_url.blank? || @push_token.blank?
    end

    def push(version:)
      articles = Article.where(content_version: version).includes(:category, :aging, :topics, :taxes,
                                                                    :industries, :tags, :attachments)
      total = articles.count
      if total.zero?
        puts "[Publish] version=#{version} 没有记录需要推送"
        return
      end

      puts "[Publish] 开始推送 #{total} 条记录 (version=#{version}) 到 D1..."
      articles.find_in_batches(batch_size: BATCH_SIZE) do |batch|
        payload = {
          content_version: version,
          articles: batch.map { |a| serialize(a) }
        }
        post_batch(payload)
        puts "[Publish] 已推送 #{batch.size} 条 (batch)"
      end
      puts "[Publish] 全部推送完成"
    end

    private

    def post_batch(payload)
      uri = URI.parse(@push_url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == "https"

      req = Net::HTTP::Post.new(uri)
      req["Content-Type"] = "application/json"
      req["Authorization"] = "Bearer #{@push_token}"
      req.body = JSON.generate(payload)

      res = http.request(req)
      return if res.is_a?(Net::HTTPSuccess)

      raise "[Publish] 推送失败: HTTP #{res.code} #{res.body}"
    end

    def serialize(article)
      {
        code: article.code,
        origin_url: article.origin_url,
        title: article.title,
        content: article.content,
        short_content: article.short_content,
        publisher: article.publisher,
        purpose: article.purpose_before_type_cast,
        doc_type: article.doc_type,
        doc_year: article.doc_year,
        doc_no: article.doc_no,
        doc_number: article.doc_number,
        notice: article.notice,
        published_at: article.published_at&.iso8601,
        category: article.category&.title,
        aging: article.aging&.title,
        parent_article_code: article.parent_article&.code,
        child_article_code: article.child_article&.code,
        topics: article.topics.map(&:title),
        taxes: article.taxes.map(&:title),
        industries: article.industries.map(&:title),
        tags: article.tags.map(&:title),
        attachments: article.attachments.map { |a| { title: a.title, source_url: a.source_url, file_type: a.file_type } },
        content_version: article.content_version
      }
    end
  end
end

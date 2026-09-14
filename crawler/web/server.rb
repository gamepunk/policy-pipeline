# frozen_string_literal: true

# 本地管理后台(web/server.rb):直接操作 content.sqlite 权威库,改完 rake publish 推送到 D1。
# 复用现有 ActiveRecord 模型,跑在 localhost,无需鉴权。

ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../Gemfile", __dir__)
require "bundler/setup"
$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))

require "app"
require "sinatra"

Database.setup!

set :views, File.expand_path("views", __dir__)
set :public_folder, File.expand_path("public", __dir__)
# 关闭 ERB 自动转义:字段已通过 h() 手动转义,正文需要输出原始 HTML
set :erb, escape_html: false

helpers do
  def h(text)
    Rack::Utils.escape_html(text.to_s)
  end

  def paging_url(page)
    url = request.path_info.dup
    params = request.GET.merge("page" => page)
    qs = params.map { |k, v| "#{Rack::Utils.escape(k)}=#{Rack::Utils.escape(v)}" }.join("&")
    "#{url}?#{qs}"
  end

  # 把树形记录(parent_id)展开成带缩进的 [显示文案, 真实值] 列表,供 <select> 使用
  def tree_options(records)
    by_parent = records.group_by(&:parent_id)
    options = []
    walk = lambda do |parent_id, depth|
      (by_parent[parent_id] || []).each do |r|
        prefix = depth.positive? ? ("　" * (depth - 1)) + "└ " : ""
        options << ["#{prefix}#{r.title}", r.title]
        walk.call(r.id, depth + 1)
      end
    end
    walk.call(nil, 0)
    options
  end

  # 把 content 里指向其他文章的外链重写为本地 /articles/:id。
  # 官方链接形如 .../c栏目ID/c文章code/content.html,取 content.html 前面的 c(\d+) 作 code。
  def rewrite_content_links(html)
    return html if html.blank?

    codes = html.scan(%r{/c(\d+)/content\.html}).flatten.uniq
    return html if codes.empty?

    id_by_code = Article.where(code: codes).pluck(:code, :id).to_h
    return html if id_by_code.empty?

    html.gsub(%r{href=(["'])[^"']*/c(\d+)/content\.html\1}) do
      code = Regexp.last_match(2)
      id_by_code.key?(code) ? "href=#{Regexp.last_match(1)}/articles/#{id_by_code[code]}#{Regexp.last_match(1)}" : Regexp.last_match(0)
    end
  end

  # 渲染 content HTML:正文注释/空链接等已在入库时清洗(Sanitizer.clean_html),
  # 这里只做展示层 XSS 防护 + 内部链接重写。
  def render_content(html)
    return "" if html.blank?

    safe = html
      .gsub(%r{<script\b[^>]*>.*?</script>}mi, "")
      .gsub(%r{<style\b[^>]*>.*?</style>}mi, "")
      .gsub(/\son\w+\s*=\s*("[^"]*"|'[^']*')/i, "")
      .gsub(/javascript:/i, "")
    rewrite_content_links(safe)
  end
end

# ---- index:列表 + 搜索 + 分页 ----
get "/" do
  @q = params[:q].to_s.strip
  @page = [params[:page].to_i, 1].max
  per = 20

  # 按发布时间倒序(最新在前);发布时间为空的排最后
  scope = Article.includes(:category).order(Arel.sql("published_at IS NULL, published_at DESC, id DESC"))
  unless @q.empty?
    like = "%#{@q}%"
    scope = scope.where("title LIKE ? OR code LIKE ? OR doc_number LIKE ?", like, like, like)
  end

  @total = scope.count
  @pages = [(@total.to_f / per).ceil, 1].max
  @articles = scope.offset((@page - 1) * per).limit(per).to_a

  erb :index
end

# ---- show:详情 ----
get "/articles/:id" do
  @article = Article.includes(
    :category, :aging, :policy, :interpretations, :attachments,
    :topics, :industries, :related_articles
  ).find_by(id: params[:id])
  halt 404, "未找到文章 ##{params[:id]}" unless @article

  erb :show
end

# ---- edit:编辑表单 ----
get "/articles/:id/edit" do
  @article = Article.includes(:topics, :industries).find_by(id: params[:id])
  halt 404, "未找到文章 ##{params[:id]}" unless @article

  @categories = tree_options(Category.order(:title).to_a)
  @agings = Aging.order(:title).pluck(:title)
  @topics = tree_options(Topic.order(:title).to_a)
  @industries = Industry.order(:id).pluck(:title)
  erb :edit
end

# ---- update:保存 ----
post "/articles/:id" do
  @article = Article.find_by(id: params[:id])
  halt 404, "未找到文章 ##{params[:id]}" unless @article

  @article.title = Sanitizer.clean(params[:title])
  @article.content = Sanitizer.clean_html(params[:content])
  @article.short_content = Sanitizer.clean(params[:short_content])
  @article.publisher = Sanitizer.clean(params[:publisher])
  @article.doc_type = Sanitizer.clean(params[:doc_type])
  @article.doc_year = params[:doc_year].presence&.to_i
  @article.doc_no = params[:doc_no].presence&.to_i
  @article.doc_number = Sanitizer.clean(params[:doc_number])
  @article.published_at = params[:published_at].presence
  @article.category = Category.find_or_create_by(title: Sanitizer.clean(params[:category])) if params[:category].present?
  @article.aging = Aging.find_or_create_by(title: Sanitizer.clean(params[:aging])) if params[:aging].present?

  # 多对多:多选下拉提交数组,先清空再重建
  { topics: Topic, industries: Industry }.each do |name, model|
    titles = Array(params[name]).map { |t| Sanitizer.clean(t) }.compact.reject(&:empty?)
    records = titles.map { |t| model.find_or_create_by(title: t) }
    @article.public_send("#{name}=", records)
  end

  @article.mark_dirty! # 内容变化,归零 version,下次 publish 重新推送
  @article.save!

  redirect "/articles/#{@article.id}"
end

Sinatra::Application.run!

# frozen_string_literal: true

# 官方接口返回的文本里常见的特殊字符清洗。
# 这是唯一的"数据清洗"环节——数据源本身够干净,不需要人工审核,
# 只需要在写库前处理掉这些已知会出问题的字符。
module Sanitizer
  # 需删除的不可见字符(不含 \u00A0,它单独转成普通空格)。
  # U+2002 等空白若只靠 Article 的 before_save 删除,会导致 clean 结果与存库值不一致、
  # 每次 fetch 都误判"内容变化",故在此与 before_save 同步删除。
  INVISIBLE_RE = /[\u2000-\u200f\u2028\u2029\u202f\u205f\u3000\uFEFF]/

  # HTML 清洗正则(供 clean_html 与 DataChecker 共用,保证规则唯一)
  COMMENT_RE = /<!--.*?-->/m
  POLLUTED_MAILTO_RE = %r{https?://[^/?#\s"']*?mailto:}i
  EMPTY_ANCHOR_RE = %r{<a\b[^>]*>\s*</a>}i
  PUNCT_ANCHOR_RE = %r{<a\b[^>]*>\s*[^\p{Han}a-zA-Z0-9<]*\s*</a>}i

  REPLACEMENTS = {
    "\u00A0" => " ",   # 不间断空格 &nbsp; → 普通空格
    "&nbsp;" => " ",
    "\r\n" => "\n",
    "\r" => "\n"
  }.freeze

  module_function

  def clean(text)
    return text if text.nil?

    text.to_s
       .gsub(INVISIBLE_RE, "")
       .gsub("\u00A0", " ")
       .gsub("&nbsp;", " ")
       .gsub("\r\n", "\n")
       .gsub("\r", "\n")
       .strip
  end

  # 清洗正文 HTML:在 clean 基础上移除 HTML 注释与无效锚点链接。
  # 官方把部分"原文跳转"锚文本用注释包住(<!--xxx-->)或只留残留标点,
  # 渲染出来是空文本死链,入库时直接清掉。
  def clean_html(html)
    return html if html.nil?

    clean(html)
      .gsub(COMMENT_RE, "")
      .gsub(POLLUTED_MAILTO_RE, "mailto:")
      .gsub(EMPTY_ANCHOR_RE, "")
      .gsub(PUNCT_ANCHOR_RE, "")
  end

  # URL 规范化:http→https;zcfgk 内容统一到 fgk.chinatax.gov.cn 域
  # (官方 API 有时返回 www.chinatax.gov.cn/zcfgk/...,该域对 zcfgk 返回 404)
  def normalize_url(url)
    url.to_s.strip
       .gsub(/^http:/, "https:")
       .sub("www.chinatax.gov.cn/zcfgk/", "fgk.chinatax.gov.cn/zcfgk/")
  end
end

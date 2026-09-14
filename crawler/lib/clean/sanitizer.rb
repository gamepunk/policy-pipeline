# frozen_string_literal: true

# 官方接口返回的文本里常见的特殊字符清洗。
# 这是唯一的"数据清洗"环节——数据源本身够干净,不需要人工审核,
# 只需要在写库前处理掉这些已知会出问题的字符。
module Sanitizer
  REPLACEMENTS = {
    "\u00A0" => " ",   # 不间断空格 &nbsp;
    "\uFEFF" => "",    # BOM
    "\u200B" => "",    # 零宽空格
    "&nbsp;" => " ",
    "\r\n" => "\n",
    "\r" => "\n"
  }.freeze

  module_function

  def clean(text)
    return text if text.nil?

    cleaned = REPLACEMENTS.reduce(text.to_s) { |str, (from, to)| str.gsub(from, to) }
    cleaned.strip
  end
end

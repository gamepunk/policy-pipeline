# frozen_string_literal: true

# 数据完整性校验:检查 content.sqlite 是否符合数据规范(关联关系、清洗规则、空值)。
# 供 rake check 调用,返回问题描述数组(空数组 = 全部通过)。
# 清洗相关的正则直接复用 Sanitizer 的常量,保证规则唯一。
module Check
  module_function

  def run
    conn = ActiveRecord::Base.connection
    [
      orphan_issue(conn),
      bad_parent_issue(conn),
      no_tax_issue(conn),
      blank_issue(conn),
      bad_url_issue(conn),
      dirty_content_issue(conn),
      dirty_fields_issue,
      empty_anchor_issue
    ].compact
  end

  # 文字解读必须关联到一篇政策(policy)
  def orphan_issue(conn)
    count = conn.select_value(<<~SQL).to_i
      SELECT count(*) FROM articles a
      JOIN categories c ON c.id = a.category_id
      WHERE c.title = '文字政策解读' AND a.policy_id IS NULL
        AND a.code NOT IN ('5242137', '5248633', '5236541', '5246741')
    SQL
    "#{count} 篇解读文章未关联政策" if count > 0
  end

  # 解读的父文章必须是政策(不能为空或也是解读)
  def bad_parent_issue(conn)
    count = conn.select_value(<<~SQL).to_i
      SELECT count(*) FROM articles a
      JOIN categories c ON c.id = a.category_id
      JOIN articles p ON p.id = a.policy_id
      LEFT JOIN categories pc ON pc.id = p.category_id
      WHERE c.title = '文字政策解读' AND (pc.title IS NULL OR pc.title = '文字政策解读')
    SQL
    "#{count} 篇解读的父文章不是政策" if count > 0
  end

  # topic=税收政策 的文章必须有税种叶子
  def no_tax_issue(conn)
    count = conn.select_value(<<~SQL).to_i
      SELECT count(*) FROM (
        SELECT DISTINCT at.article_id FROM articles_topics at
        JOIN topics t ON t.id = at.topic_id WHERE t.title = '税收政策'
      ) tx WHERE tx.article_id NOT IN (
        SELECT DISTINCT at.article_id FROM articles_topics at
        JOIN topics t ON t.id = at.topic_id
        WHERE t.parent_id = (SELECT id FROM topics WHERE title = '税收政策')
      )
    SQL
    "#{count} 篇税收政策文章无税种" if count > 0
  end

  # 空值必须是 SQL NULL,不能是空字符串/纯空白
  def blank_issue(conn)
    count = conn.select_value(<<~SQL).to_i
      SELECT count(*) FROM articles WHERE
        code = '' OR origin_url = '' OR title = '' OR content = '' OR
        short_content = '' OR publisher = '' OR doc_type = '' OR doc_number = '' OR notice = ''
    SQL
    "#{count} 个字段为空字符串" if count > 0
  end

  # origin_url 必须已规范化:https + fgk 域(无 www/zcfgk、无旧 IP 死链)
  def bad_url_issue(conn)
    count = conn.select_value(<<~SQL).to_i
      SELECT count(*) FROM articles WHERE
        origin_url LIKE 'http://%'
        OR origin_url LIKE '%www.chinatax.gov.cn/zcfgk/%'
        OR origin_url LIKE '%100.12.64.119%'
    SQL
    "#{count} 条 origin_url 未规范化" if count > 0
  end

  # content 必须已清洗:无 HTML 注释、无旧 IP 死链、无 mailto 污染
  def dirty_content_issue(conn)
    count = conn.select_value(<<~SQL).to_i
      SELECT count(*) FROM articles WHERE
        content LIKE '%<!--%'
        OR content LIKE '%100.12.64.119%'
        OR content LIKE '%80mailto:%'
    SQL
    "#{count} 条 content 未清洗" if count > 0
  end

  # 文本字段不得残留不可见字符 / HTML 实体 / 回车
  def dirty_fields_issue
    count = 0
    Article.find_each do |a|
      count += 1 if Article::BLANKABLE_COLUMNS.any? do |col|
        v = a[col]
        v.is_a?(String) &&
          (v.match?(Sanitizer::INVISIBLE_RE) || v.include?("&nbsp;") || v.include?("\r"))
      end
    end
    "#{count} 条记录含未清洗字段" if count > 0
  end

  # content 不得残留空锚文本或纯标点锚文本链接
  def empty_anchor_issue
    count = 0
    Article.where.not(content: nil).find_each do |a|
      if a.content.match?(Sanitizer::EMPTY_ANCHOR_RE) ||
         a.content.match?(Sanitizer::PUNCT_ANCHOR_RE)
        count += 1
      end
    end
    "#{count} 条 content 残留空锚文本链接" if count > 0
  end
end

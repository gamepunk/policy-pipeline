# frozen_string_literal: true

class Article < ActiveRecord::Base
  INTERPRETATION_ROOT = "政策解读"

  # 这些字段保存前统一空值规范化:空字符串/纯空白一律存 NULL。
  # 不可见字符与首尾空白的清洗统一由 Sanitizer 负责(所有写入点都走 Sanitizer)。
  BLANKABLE_COLUMNS = %w[code origin_url title content short_content publisher doc_type doc_number notice].freeze

  belongs_to :category, optional: true
  belongs_to :aging, optional: true
  belongs_to :policy, class_name: "Article", optional: true
  has_many :interpretations, class_name: "Article", foreign_key: :policy_id

  has_many :attachments, dependent: :destroy

  has_and_belongs_to_many :topics, join_table: "articles_topics"
  has_and_belongs_to_many :industries, join_table: "articles_industries"
  has_and_belongs_to_many :related_articles, class_name: "Article",
                                              join_table: "articles_related_articles",
                                              association_foreign_key: "related_article_id"

  # 尚未被 publish 命令推送过 / 或推送之后内容又变了,都是 version == 0
  scope :pending_publish, -> { where(version: 0) }
  scope :interpretation, -> { where(category_id: Category.interpretation_ids) }
  scope :policy, -> { where.not(category_id: Category.interpretation_ids) }

  before_save :nullify_blank_fields

  def interpretation?
    category&.ancestors&.any? { |c| c.title == INTERPRETATION_ROOT }
  end

  def policy?
    !interpretation?
  end

  def mark_dirty!
    # 内容发生变化时调用:归零 version,下次 publish 会重新推送这条
    update_column(:version, 0) if version != 0
  end

  private

  def nullify_blank_fields
    BLANKABLE_COLUMNS.each do |col|
      value = self[col]
      next unless value.is_a?(String)

      self[col] = value.presence
    end
  end
end

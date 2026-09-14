# frozen_string_literal: true

class Article < ActiveRecord::Base
  enum :purpose, { policy: 0, interpretation: 1 }

  belongs_to :category, optional: true
  belongs_to :aging, optional: true
  belongs_to :parent_article, class_name: "Article", optional: true
  belongs_to :child_article, class_name: "Article", optional: true

  has_many :attachments, dependent: :destroy

  has_and_belongs_to_many :topics, join_table: "articles_topics"
  has_and_belongs_to_many :taxes, join_table: "articles_taxes"
  has_and_belongs_to_many :industries, join_table: "articles_industries"
  has_and_belongs_to_many :tags, join_table: "articles_tags"
  has_and_belongs_to_many :collections, join_table: "articles_collections"
  has_and_belongs_to_many :related_articles, class_name: "Article",
                                              join_table: "articles_related_articles",
                                              association_foreign_key: "related_article_id"

  validates :purpose, presence: true

  # 尚未被 publish 命令推送过 / 或推送之后内容又变了,都是 content_version == 0
  scope :pending_publish, -> { where(content_version: 0) }

  def mark_dirty!
    # 内容发生变化时调用:归零 content_version,下次 publish 会重新推送这条
    update_column(:content_version, 0) if content_version != 0
  end
end

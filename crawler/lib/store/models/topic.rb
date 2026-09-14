# frozen_string_literal: true

class Topic < ActiveRecord::Base
  belongs_to :parent, class_name: "Topic", optional: true
  has_many :children, class_name: "Topic", foreign_key: :parent_id
  has_and_belongs_to_many :articles, join_table: "articles_topics"
  validates :title, presence: true, uniqueness: true

  # 从根到自己的祖先链(含自身)
  def ancestors
    result = []
    node = self
    while node
      result << node
      node = node.parent
    end
    result
  end

  # 所有子孙(不含自身)
  def descendants
    result = []
    queue = children.to_a
    while queue.any?
      node = queue.shift
      result << node
      queue.concat(node.children.to_a)
    end
    result
  end
end

# frozen_string_literal: true

class Category < ActiveRecord::Base
  belongs_to :parent, class_name: "Category", optional: true
  has_many :children, class_name: "Category", foreign_key: :parent_id
  has_many :articles
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

  # 解读分类树的所有节点 id(根+子+孙+曾孙,最多四层)
  def self.interpretation_ids
    root = find_by(title: Article::INTERPRETATION_ROOT)
    return [] unless root

    level2 = where(parent_id: root.id).pluck(:id)
    level3 = where(parent_id: level2).pluck(:id)
    level4 = where(parent_id: level3).pluck(:id)
    ([root.id] + level2 + level3 + level4).uniq
  end
end

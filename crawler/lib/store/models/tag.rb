# frozen_string_literal: true

class Tag < ActiveRecord::Base
  has_and_belongs_to_many :articles, join_table: "articles_tags"
  validates :title, presence: true, uniqueness: true
end

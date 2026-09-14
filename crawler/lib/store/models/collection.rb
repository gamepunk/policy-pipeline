# frozen_string_literal: true

class Collection < ActiveRecord::Base
  has_and_belongs_to_many :articles, join_table: "articles_collections"
  validates :title, presence: true, uniqueness: true
end

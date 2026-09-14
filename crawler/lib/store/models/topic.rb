# frozen_string_literal: true

class Topic < ActiveRecord::Base
  has_and_belongs_to_many :articles, join_table: "articles_topics"
  validates :title, presence: true, uniqueness: true
end

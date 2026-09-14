# frozen_string_literal: true

class Industry < ActiveRecord::Base
  has_and_belongs_to_many :articles, join_table: "articles_industries"
  validates :title, presence: true, uniqueness: true
end

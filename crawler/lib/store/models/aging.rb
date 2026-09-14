# frozen_string_literal: true

class Aging < ActiveRecord::Base
  has_many :articles
  validates :title, presence: true, uniqueness: true
end

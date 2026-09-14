# frozen_string_literal: true

class Attachment < ActiveRecord::Base
  belongs_to :article
  validates :source_url, presence: true, uniqueness: { scope: :article_id }
end

# frozen_string_literal: true

# key-value 表,目前只存 content_version。
class Meta < ActiveRecord::Base
  self.primary_key = "key"

  def self.get(key)
    find_by(key: key)&.value
  end

  def self.set(key, value)
    record = find_or_initialize_by(key: key)
    record.value = value.to_s
    record.save!
    value
  end

  def self.content_version
    (get("content_version") || "0").to_i
  end
end

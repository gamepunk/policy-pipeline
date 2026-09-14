# frozen_string_literal: true

require "time"

module Clock
  module_function

  def parse(raw)
    return nil if raw.nil? || raw.to_s.strip.empty?

    Time.parse(raw.to_s)
  rescue ArgumentError => e
    App.logger.warn("[Clock] 时间解析失败: #{raw} (#{e.message})")
    nil
  end
end

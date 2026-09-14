# frozen_string_literal: true

require "active_record"
require "logger"
require "time"
require "set"

module App
  class << self
    def logger
      @logger ||= Logger.new($stdout).tap do |l|
        l.formatter = proc { |_sev, time, _prog, msg| "[#{time.strftime('%H:%M:%S')}] #{msg}\n" }
      end
    end
  end
end

# 支撑(横切基础设施)
require_relative "support/loader"
require_relative "support/lock"
require_relative "support/mapper"
require_relative "support/cache"
require_relative "support/progress"

# 清洗
require_relative "clean/clock"
require_relative "clean/sanitizer"

# 存储
require_relative "store/database"
require_relative "store/models/article"
require_relative "store/models/category"
require_relative "store/models/aging"
require_relative "store/models/topic"
require_relative "store/models/industry"
require_relative "store/models/attachment"
require_relative "store/models/meta"

# 抓取
require_relative "ingest/client"
require_relative "ingest/runner"
require_relative "ingest/search"
require_relative "ingest/fetch"

# 发布
require_relative "publish/bumper"
require_relative "publish/d1"

# 校验
require_relative "support/check"

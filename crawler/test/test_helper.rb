# frozen_string_literal: true

# 测试统一入口:固定用 crawler/Gemfile 的 bundle,内存 SQLite + 迁移建表,
# 每个用例用事务包裹、结束回滚,保证隔离。

ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../Gemfile", __dir__)
require "bundler/setup"

$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))

require "minitest/autorun"
require "app"

MIGRATION_FILE = File.expand_path("../../database/migrations/001_initial.sql", __dir__)

ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Base.connection.raw_connection.execute_batch(File.read(MIGRATION_FILE))

# 事务隔离:mixin 后每个测试在事务内运行,teardown 回滚
module TransactionalTestCase
  def setup
    ActiveRecord::Base.connection.begin_transaction(joinable: false)
  end

  def teardown
    ActiveRecord::Base.connection.rollback_transaction
  end
end

# 假 HTTP 响应:不依赖 Net::HTTPResponse 的内部读取状态,
# 只暴露 Client 用到的 code / body,并按状态码模拟 is_a?(Net::HTTPSuccess)
class FakeResponse
  attr_reader :code, :body

  def initialize(body, code: "200")
    @body = body
    @code = code.to_s
  end

  def is_a?(klass)
    klass == Net::HTTPSuccess ? code.to_i.between?(200, 299) : super
  end
end

# 构造假 HTTP transport 与响应,让 Client 测试不触网
module HttpTestHelpers
  def fake_response(body, code: "200")
    FakeResponse.new(body, code: code)
  end

  def fake_transport(body, code: "200")
    response = fake_response(body, code: code)
    Object.new.tap do |t|
      t.define_singleton_method(:request) { |_req| response }
    end
  end
end

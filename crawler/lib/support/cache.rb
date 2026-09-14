# frozen_string_literal: true

require "sqlite3"
require "fileutils"

# 官方 API 响应本地缓存,单文件 SQLite 存储(crawler/tmp/cache.sqlite)。
# 相比"每个响应一个文件"的方案,单文件避免目录里堆积数千文件,
# 读写走 B-tree 索引,并发由 SQLite 自己串行化,天然安全。
# 目的:测试/调试时避免重复请求 API 触发限流。
module Cache
  DB_FILENAME = "cache.sqlite"

  class << self
    # 是否启用缓存:环境变量 CACHE=off/0 强制关闭;@disabled 供测试进程内关闭。
    def enabled?
      return false if ENV["CACHE"] == "off" || ENV["CACHE"] == "0"
      return false if @disabled

      Loader.current.dig("cache", "enabled") != false
    end

    # 离线模式:只读缓存,绝不发网络请求。
    # 环境变量 OFFLINE=1/true 或配置 cache.offline 开启。
    def offline?
      return true if ENV["OFFLINE"] == "1" || ENV["OFFLINE"] == "true"

      Loader.current.dig("cache", "offline") == true
    end

    # 命中返回响应体字符串;未命中、已过期返回 nil。
    def fetch(key)
      return nil unless enabled?

      with_connection do |db|
        row = db.get_first_row("SELECT body, created_at FROM cache WHERE key = ?", key)
        return nil unless row

        body, created_at = row
        if expired?(created_at)
          db.execute("DELETE FROM cache WHERE key = ?", key)
          return nil
        end

        body
      end
    rescue SQLite3::Exception
      nil
    end

    # 写入响应体,INSERT OR REPLACE 保证幂等。kind 标记来源:search / fetch。
    def store(key, body, kind:)
      return unless enabled?
      return if body.nil?

      with_connection do |db|
        db.execute(
          "INSERT OR REPLACE INTO cache (key, kind, body, created_at) VALUES (?, ?, ?, ?)",
          [key, kind, body, Time.now.to_i]
        )
      end
      body
    rescue SQLite3::Exception
      nil
    end

    # 进程内开关,测试里关闭以避免把假响应写进真实缓存库
    def disable!
      @disabled = true
    end

    def enable!
      @disabled = false
    end

    def clear!
      FileUtils.rm_f(db_path)
      Thread.current[:cache_connection] = nil
    end

    def stats
      with_connection do |db|
        db.execute("SELECT kind, count(*) FROM cache GROUP BY kind").to_h
      end
    rescue SQLite3::Exception
      {}
    end

    def db_path
      # __dir__ 是 crawler/lib/support,上两级是 crawler,缓存落在 crawler/tmp/cache.sqlite
      File.expand_path("../../tmp/#{DB_FILENAME}", __dir__)
    end

    def ttl_seconds
      (ENV["CACHE_TTL"] || Loader.current.dig("cache", "ttl_seconds") || 0).to_i
    end

    private

    # 每个线程持有一个 SQLite 连接,避免跨线程共享连接的隐患。
    # CLI 进程结束后连接随进程销毁,无需显式关闭。
    def with_connection
      conn = Thread.current[:cache_connection] ||= build_connection
      yield conn
    end

    def build_connection
      FileUtils.mkdir_p(File.dirname(db_path))
      db = SQLite3::Database.new(db_path)
      db.busy_timeout = 5000
      db.execute("PRAGMA journal_mode=WAL")
      db.execute(<<~SQL)
        CREATE TABLE IF NOT EXISTS cache (
          key TEXT PRIMARY KEY,
          kind TEXT NOT NULL,
          body TEXT NOT NULL,
          created_at INTEGER NOT NULL
        );
      SQL
      # 兼容旧库:早期版本没有 kind 列,自动补齐
      columns = db.execute("PRAGMA table_info(cache)").map { |row| row[1] }
      db.execute("ALTER TABLE cache ADD COLUMN kind TEXT NOT NULL DEFAULT 'unknown'") unless columns.include?("kind")
      db.execute("CREATE INDEX IF NOT EXISTS idx_cache_kind ON cache(kind)")
      db
    end

    def expired?(created_at)
      ttl = ttl_seconds
      return false if ttl <= 0 # 0 或负数 = 永不过期,靠手动 clear

      Time.now.to_i - created_at.to_i > ttl
    end
  end
end

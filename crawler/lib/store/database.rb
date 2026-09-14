# frozen_string_literal: true

require "active_record"
require "fileutils"

# 连接 database/content.sqlite,并执行 database/migrations/*.sql。
# migration 用纯 SQL 文件(不是 ActiveRecord::Migration DSL),
# 这样同一份 schema 文件可以直接喂给 Cloudflare D1(wrangler d1 migrations apply)。
module Database
  module_function

  # db_path 可注入,测试时传临时文件或 ":memory:",避免依赖真实 content.sqlite
  def setup!(db_path: nil)
    db_path ||= resolve_db_path
    FileUtils.mkdir_p(File.dirname(db_path))

    ActiveRecord::Base.establish_connection(
      adapter: "sqlite3",
      database: db_path,
      timeout: 5000
    )
    ActiveRecord::Base.logger = ENV["DEBUG"] ? App.logger : nil

    # SQLite 并发写入很弱,WAL 模式能缓解"database is locked"问题。
    # 即便如此,业务代码仍遵循"多线程只读请求 + 单线程写入"的原则。
    ActiveRecord::Base.connection.execute("PRAGMA journal_mode=WAL")
    ActiveRecord::Base.connection.execute("PRAGMA foreign_keys=ON")
  end

  def migrate!
    ensure_schema_migrations_table

    applied = applied_versions
    migration_files.each do |path|
      version = File.basename(path, ".sql")
      next if applied.include?(version)

      puts "[Database] 执行迁移 #{File.basename(path)}"
      sql = File.read(path)
      raw_connection.execute_batch(sql)
      record_migration(version)
    end
  end

  def migration_files
    dir = File.expand_path("../../../database/migrations", __dir__)
    Dir.glob(File.join(dir, "*.sql")).sort
  end

  def resolve_db_path
    relative = Loader.current.dig("database", "path") || "../database/content.sqlite"
    File.expand_path(relative, File.dirname(Loader.settings_path))
  end

  def raw_connection
    ActiveRecord::Base.connection.raw_connection
  end

  def ensure_schema_migrations_table
    raw_connection.execute_batch(<<~SQL)
      CREATE TABLE IF NOT EXISTS schema_migrations (
        version TEXT PRIMARY KEY,
        applied_at DATETIME NOT NULL
      );
    SQL
  end

  def applied_versions
    ActiveRecord::Base.connection.select_values("SELECT version FROM schema_migrations").to_set
  end

  def record_migration(version)
    ActiveRecord::Base.connection.execute(
      "INSERT INTO schema_migrations (version, applied_at) VALUES (#{ActiveRecord::Base.connection.quote(version)}, datetime('now'))"
    )
  end

  # 生成 Rails 风格的 database/schema.rb(自动生成,方便人工检查结构)。
  # 该文件不参与建表,建表仍由 migrations/*.sql 负责。
  def dump_schema!
    require "active_record/schema_dumper"
    path = schema_path
    File.open(path, "w") do |io|
      ActiveRecord::SchemaDumper.dump(ActiveRecord::Base.connection_pool, io)
    end
    puts "[Database] 已生成 #{path}"
    path
  end

  def schema_path
    File.expand_path("../../../database/schema.rb", __dir__)
  end
end

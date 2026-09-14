# frozen_string_literal: true

require "rake/testtask"

# 固定使用 crawler/Gemfile,并加载其依赖(activesupport / activerecord / sqlite3)
ENV["BUNDLE_GEMFILE"] ||= File.expand_path("crawler/Gemfile", __dir__)
require "bundler/setup"
$LOAD_PATH.unshift(File.expand_path("crawler/lib", __dir__))

Rake::TestTask.new(:test) do |t|
  t.libs << "crawler/lib" << "crawler/test"
  t.pattern = "crawler/test/**/*_test.rb"
end

# 懒加载 app,避免 rake test / rake -T 也加载全部 models
def load_app!
  require "app"
end

def current_concurrency
  value = ENV["CONCURRENCY"]&.to_i
  value&.positive? ? value : nil
end

namespace :db do
  desc "初始化数据库并执行所有迁移"
  task :setup do
    load_app!
    Database.setup!
    Database.migrate!
    puts "[DB] 完成"
  end

  desc "执行尚未应用的迁移"
  task :migrate do
    load_app!
    Database.setup!
    Database.migrate!
    puts "[DB] 迁移完成"
  end
end

desc "全量抓取政策列表(可用 CONCURRENCY 指定并发数)"
task :search do
  load_app!
  Database.setup!
  searcher = Search.new
  current_concurrency ? searcher.search_all(concurrency: current_concurrency) : searcher.search_all
end

desc "增量抓取政策列表"
task "search:incremental" do
  load_app!
  Database.setup!
  Search.new.search_incremental
end

desc "抓取详情正文并建立关联(可用 PURPOSE=policy|interpretation、CONCURRENCY 指定并发)"
task :fetch do
  load_app!
  Database.setup!
  opts = current_concurrency ? { concurrency: current_concurrency } : {}
  Fetch.new.fetch_all(purpose: ENV["PURPOSE"], **opts)
end

desc "把待发布记录推送到 D1"
task :publish do
  load_app!
  Database.setup!
  result = Publish::Bumper.bump!
  Publish::D1.new.push(version: result[:version]) unless result[:count].zero?
end

desc "查看数据库状态概览"
task :status do
  load_app!
  Database.setup!
  puts "content_version(已发布): #{Meta.content_version}"
  puts "文章总数: #{Article.count}"
  puts "待发布: #{Article.pending_publish.count}"
  puts "政策: #{Article.policy.count} / 政策解读: #{Article.interpretation.count}"
end

desc "常规日更新: 增量抓取列表 -> 抓取详情 -> 发布"
task update: ["search:incremental", :fetch, :publish]

namespace :server do
  desc "安装 Worker 依赖"
  task :install do
    cd "server" do
      sh "npm install"
    end
  end

  desc "启动 Worker 本地开发"
  task :dev do
    cd "server" do
      sh "npm run dev"
    end
  end

  desc "部署 Worker 到 Cloudflare"
  task :deploy do
    cd "server" do
      sh "npm run deploy"
    end
  end

  desc "生成 Worker 类型声明"
  task :types do
    cd "server" do
      sh "npm run types"
    end
  end

  desc "查看 Worker 实时日志"
  task :tail do
    cd "server" do
      sh "npx wrangler tail"
    end
  end

  desc "查看 Cloudflare 登录状态"
  task :whoami do
    cd "server" do
      sh "npx wrangler whoami"
    end
  end

  desc "创建 D1 数据库(会输出 database_id,需填入 wrangler.jsonc)"
  task "d1:create" do
    cd "server" do
      sh "npx wrangler d1 create taxman-content"
    end
  end

  desc "本地应用 D1 迁移"
  task "d1:migrate:local" do
    cd "server" do
      sh "npm run d1:migrate:local"
    end
  end

  desc "远程应用 D1 迁移"
  task "d1:migrate:remote" do
    cd "server" do
      sh "npm run d1:migrate:remote"
    end
  end
end

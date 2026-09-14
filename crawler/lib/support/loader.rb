# frozen_string_literal: true

require "yaml"
require "erb"

# 加载 crawler/config/settings.yml(可提交 Git)+ crawler/config/secrets(gitignore,dotenv 格式)。
# 项目结构是固定的(不是通用工具,不需要 `init` 在任意目录生成配置),
# 所以直接按相对路径找,不需要向上查找项目根目录。
module Loader
  class NotFoundError < StandardError; end

  module_function

  def crawler_root
    # __dir__ 是 crawler/lib/support,上两级就是 crawler
    File.expand_path("../..", __dir__)
  end

  def settings_path
    File.join(crawler_root, "config", "settings.yml")
  end

  def secrets_path
    File.join(crawler_root, "config", "secrets")
  end

  def current
    @current ||= load_config
  end

  def reset!
    @current = nil
  end

  def load_config
    path = settings_path
    raise NotFoundError, "未找到 #{path}" unless File.exist?(path)

    load_secrets(secrets_path) if File.exist?(secrets_path)

    erb_result = ERB.new(File.read(path)).result
    YAML.safe_load(erb_result, aliases: true) || {}
  end

  # 极简 dotenv:解析 KEY=VALUE,写入 ENV(不覆盖已存在的)
  def load_secrets(path)
    File.readlines(path).each do |line|
      line = line.strip
      next if line.empty? || line.start_with?("#")

      key, value = line.split("=", 2)
      next unless key && value

      ENV[key.strip] ||= value.strip.gsub(/\A["']|["']\z/, "")
    end
  end
end

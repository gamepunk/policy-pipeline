# frozen_string_literal: true

require "fileutils"

# 用 File#flock 实现的单机任务锁,替代原 Rails.cache 版本。
# 进程崩溃时操作系统会自动释放锁,不需要手动管理 TTL 过期。
module Lock
  class << self
    def with_lock(name, ttl: nil, lock_dir: default_lock_dir)
      FileUtils.mkdir_p(lock_dir)
      path = File.join(lock_dir, "#{sanitize(name)}.lock")

      break_stale_lock(path, ttl) if ttl

      file = File.open(path, File::CREAT | File::RDWR)
      acquired = file.flock(File::LOCK_EX | File::LOCK_NB)

      unless acquired
        file.close
        return false
      end

      begin
        File.write(path, Process.pid.to_s)
        yield
        true
      ensure
        file.flock(File::LOCK_UN)
        file.close
      end
    end

    private

    def break_stale_lock(path, ttl)
      return unless File.exist?(path)
      return if (Time.now - File.mtime(path)) < ttl

      File.delete(path)
    rescue Errno::ENOENT
      # 已被其他进程清理,忽略
    end

    def sanitize(name)
      name.to_s.gsub(/[^a-zA-Z0-9_\-]/, "_")
    end

    def default_lock_dir
      # __dir__ 是 crawler/lib/support,上两级就是 crawler,锁目录落在 crawler/tmp/locks
      File.expand_path("../../tmp/locks", __dir__)
    end
  end
end

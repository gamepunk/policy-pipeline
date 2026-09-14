# frozen_string_literal: true

module Publish
  # content_version == 0 的记录代表"新增或内容有变化、尚未发布"。
  # bump! 把这批记录打上同一个新的全局版本号,并推进 meta.content_version。
  # iOS/macOS 端的增量同步就是靠这个单调递增的整数版本号做 `since=` 查询,
  # 不依赖时间戳,避免客户端/服务端时钟不一致的问题。
  module Bumper
    module_function

    def bump!
      pending = Article.pending_publish
      count = pending.count

      if count.zero?
        puts "[Publish] 没有待发布的记录"
        return { version: Meta.content_version, count: 0 }
      end

      new_version = Meta.content_version + 1

      ActiveRecord::Base.transaction do
        pending.update_all(content_version: new_version)
        Meta.set("content_version", new_version)
      end

      puts "[Publish] #{count} 条记录已标记为 content_version=#{new_version}"
      { version: new_version, count: count }
    end
  end
end

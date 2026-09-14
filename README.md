# Project

政策库内容管道:Ruby CLI 抓取官方数据 → `database/content.sqlite`(权威库,提交 Git)→ 推送到 Cloudflare D1 → iOS/macOS(SwiftData)。用户数据(收藏/批注等)完全独立,走 CloudKit,不经过这条管道。

```
Ruby CLI (search / fetch / publish)
        ↓
database/content.sqlite  (唯一权威库,同时也是 App 的种子数据)
        ↓ publish
     Cloudflare D1
        ↓ /content/sync?since=<version>
   iOS / macOS (SwiftData)
```

content_version 是单调递增的整数,不用时间戳做增量同步依据,避免客户端/服务端时钟不一致的问题。

## 目录结构

```
project/
├── Rakefile                  # 顶层任务,直接加载 crawler 代码
├── crawler/                   # Ruby 抓取管道,唯一能修改 content.sqlite 的组件
│   ├── Gemfile
│   ├── config/
│   │   ├── settings.yml       # 提交 Git,不含密钥
│   │   └── secrets.example    # 复制为 secrets 并填真实值,已 gitignore
│   └── lib/
│       ├── app.rb             # 主入口,统一 require
│       ├── config.rb          # 加载 config/settings.yml + secrets
│       ├── database.rb        # 连接管理 + 纯 SQL migration runner
│       ├── client.rb          # HTTP client(Net::HTTP,含重试/熔断)
│       ├── task_lock.rb       # 文件锁,防止任务并发重复执行
│       ├── error_mapper.rb
│       ├── time_helper.rb
│       ├── sanitizer.rb       # 特殊字符清洗(唯一的数据清洗环节)
│       ├── models/            # ActiveRecord models
│       ├── search.rb          # 抓取政策列表(对接官方数据源)
│       ├── fetch.rb           # 抓取详情正文 + 建立关联
│       └── publishing/        # 打版本号 + 推送到 D1
├── database/
│   ├── content.sqlite         # 权威数据,提交 Git,同时也是 App bundle 的种子数据
│   └── migrations/*.sql       # 纯 SQL,本地 SQLite 和 D1(wrangler)共用同一份文件
├── server/                     # Cloudflare Worker(TypeScript):/api/publish + /api/content/*
├── apps/                       # iOS / macOS(SwiftData + CloudKit)
└── docs/
```

## 使用

```bash
cd crawler
bundle install

cp config/secrets.example config/secrets
# 编辑 config/secrets,填入 D1_PUSH_URL / D1_PUSH_TOKEN

cd ..
rake db:setup        # 初始化 database/content.sqlite 并执行迁移

rake search          # 全量抓取政策列表
rake fetch            # 抓取详情正文,建立关联
rake publish           # 把有变化的记录打版本号推送到 D1

rake status            # 查看当前数据库状态
rake update             # 日常用:增量抓取 + 抓详情 + 发布,一条龙

# 可用环境变量:CONCURRENCY=8(并发数)、PURPOSE=policy|interpretation(fetch 过滤)
```

## 数据清洗

数据源本身结构化程度够高,不需要人工审核这一步。唯一的清洗动作是 `sanitizer.rb` 里的特殊字符替换(不间断空格、BOM、`&nbsp;` 等),在 `search`/`fetch` 写库之前自动执行。如果后续发现新的脏字符,直接在 `Sanitizer::REPLACEMENTS` 里加一条规则即可。

## 增量与幂等

- **列表增量**:`search --incremental` 按最后更新时间倒序拉取,遇到"已存在且内容 hash 未变"的记录即停止,不依赖单独的水位线字段。
- **内容变化检测**:每条记录存一个 `content_hash`,内容变了才会把 `content_version` 归零(标记为待发布),避免没有变化的数据被重复推送。
- **发布幂等**:`publish` 按 `code + purpose` upsert 推给 Worker,同一批数据重复推送不会产生副作用,推送失败可以直接重试整批。

## 待补充(不在本次代码范围内)

- `apps/`:iOS/macOS 客户端,SwiftData 模型 + 同步逻辑 + CloudKit 用户数据

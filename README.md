# policy-pipeline

政策库内容管道:Ruby CLI 抓取官方数据 → `database/content.sqlite`(本地权威库)→ 推送到 Cloudflare D1 → iOS/macOS(SwiftData)。用户数据(收藏/批注等)完全独立,走 CloudKit,不经过这条管道。

```
Ruby CLI (search / fetch / publish)
        ↓
database/content.sqlite  (本地权威库,gitignore,不提交)
        ↓ publish
     Cloudflare D1
        ↓ /api/content/sync?since=<version>&after=<cursor>
   iOS / macOS (SwiftData)
```

`version` 是单调递增的整数,不用时间戳做增量同步依据,避免客户端/服务端时钟不一致的问题。

## 目录结构

```
project/
├── Rakefile                  # 顶层任务,直接加载 crawler 代码
├── crawler/                  # Ruby 抓取管道,唯一能修改 content.sqlite 的组件
│   ├── Gemfile
│   ├── config/
│   │   ├── settings.yml      # 提交 Git,不含密钥
│   │   └── secrets.example   # 复制为 secrets 并填真实值,secrets 已 gitignore
│   ├── lib/
│   │   ├── app.rb            # 主入口,统一 require
│   │   ├── support/          # 横切基础设施
│   │   │   ├── loader.rb     # 加载 settings.yml + secrets
│   │   │   ├── lock.rb       # 文件锁,防止任务并发重复执行
│   │   │   ├── mapper.rb     # 错误信息压缩
│   │   │   ├── cache.rb      # 官方 API 响应缓存(单文件 SQLite)
│   │   │   └── progress.rb   # 终端单行进度条
│   │   ├── clean/            # 数据清洗
│   │   │   ├── clock.rb      # 时间解析
│   │   │   └── sanitizer.rb  # 特殊字符清洗(唯一的数据清洗环节)
│   │   ├── store/            # 存储
│   │   │   ├── database.rb   # 连接管理 + 纯 SQL migration runner
│   │   │   └── models/       # ActiveRecord models
│   │   ├── ingest/           # 抓取
│   │   │   ├── client.rb     # HTTP client(Net::HTTP,含重试/熔断/缓存)
│   │   │   ├── runner.rb     # 通用并发执行器
│   │   │   ├── search.rb     # 抓取政策列表
│   │   │   └── fetch.rb      # 抓取详情正文 + 建立关联
│   │   └── publish/          # 发布
│   │       ├── bumper.rb     # 打全局版本号
│   │       └── d1.rb         # 批量推送到 D1
│   └── test/                 # minitest 测试
├── database/
│   ├── content.sqlite        # 本地权威库,gitignore(靠 migrations 重建)
│   ├── schema.rb             # Rails 风格结构快照,自动生成(rake db:schema:dump)
│   └── migrations/*.sql      # 纯 SQL,本地 SQLite 和 D1 共用同一份文件
└── server/                   # Cloudflare Worker(TypeScript):/api/publish + /api/content/*
    └── src/
        ├── app.ts            # 入口 + 路由
        ├── handlers.ts       # version / sync / publish 处理器
        ├── database.ts       # D1 读写
        ├── serializer.ts     # 读库组装完整 JSON
        ├── types.ts          # 数据契约
        └── docs.ts           # Swagger UI + OpenAPI
```

## 快速开始

```bash
# 1. 安装 Ruby 依赖(版本由 mise.toml 管理:ruby 4.0.6)
cd crawler && bundle install && cd ..

# 2. 配置密钥
cp crawler/config/secrets.example crawler/config/secrets
# 编辑 secrets,填入 D1_PUSH_URL / D1_PUSH_TOKEN

# 3. 初始化数据库(建表 + 迁移 + 字典 seed)
rake db:setup

# 4. 抓取数据(全量:列表 + 详情,同时填充本地缓存)
rake rebuild

# 5. 发布到 D1
rake publish
```

## 常用命令

```bash
# 数据库
rake db:setup           # 建库 + 执行全部迁移
rake db:migrate         # 执行尚未应用的迁移
rake db:schema:dump     # 生成 Rails 风格 database/schema.rb
rake status             # 查看数据库状态概览

# 抓取
rake search             # 全量抓取政策列表
rake search:incremental # 增量抓取政策列表
rake fetch              # 抓取详情正文 + 建立关联
rake rebuild            # 全量重建:search -> fetch(优先走本地缓存)

# 发布
rake publish            # 把待发布记录打版本号推送到 D1
rake update             # 日常一条龙:增量列表 -> 详情 -> 发布

# 缓存(官方 API 响应,存 crawler/tmp/cache.sqlite)
rake cache:stats        # 查看缓存统计
rake cache:clear        # 清空缓存
OFFLINE=1 rake rebuild  # 离线模式:只读缓存,不访问 API

# 调试
rake console            # 交互式 Ruby(可操作模型与缓存)
rake db                 # 打开 content 库 SQLite 命令行
rake cache:db           # 打开 cache 库 SQLite 命令行
rake test               # 运行测试

# Worker
rake server:install     # 安装 Worker 依赖
rake server:deploy      # 部署 Worker
rake server:dev         # 本地开发
rake server:d1:migrate:remote  # 应用 D1 远程迁移
```

环境变量:`CONCURRENCY=8`(并发数)、`PURPOSE=policy|interpretation`(fetch 过滤)、`OFFLINE=1`(离线只读缓存)、`DEBUG=1`(详细日志)、`CACHE_TTL=秒`(缓存过期)。

## 本地缓存与离线测试

官方 API 响应缓存在 `crawler/tmp/cache.sqlite`(单文件 SQLite,gitignore):

- **在线抓取时自动填充** —— search / fetch 每次请求都会写缓存
- **离线重建** —— `OFFLINE=1 rake rebuild`,全程只读缓存、零网络请求、零限流风险
- **测试闭环** —— 在线抓一次填满缓存 → 之后任意次数离线秒级重建

缓存表结构:`cache(key, kind, body, created_at)`,`kind` 区分 `search` / `fetch`。

## 数据清洗

数据源本身结构化程度够高,不需要人工审核。唯一清洗动作是 `sanitizer.rb` 里的特殊字符替换(不间断空格、BOM、`&nbsp;` 等),在 `search`/`fetch` 写库前自动执行。新增脏字符直接在 `Sanitizer::REPLACEMENTS` 加规则即可。

## 增量与幂等

- **列表增量**:`search:incremental` 按最后更新时间倒序拉取,遇到"已存在且内容 hash 未变"的记录即停止。
- **内容变化检测**:每条记录存 `content_hash`,内容变了才把 `version` 归零(标记待发布),避免无变化数据被重复推送。
- **发布幂等**:`publish` 按 `code` 或 `origin_url` upsert 推给 Worker,重复推送无副作用,失败可直接重试整批。
- **同步分页**:`/api/content/sync` 用 `since` + `after` 游标分页,避免全量返回导致 Worker CPU 超时。

## Worker API

| 接口                                         | 说明                       |
| -------------------------------------------- | -------------------------- |
| `GET /api/content/version`                   | 当前全局版本号             |
| `GET /api/content/sync?since=&after=&limit=` | 增量同步(游标分页)         |
| `POST /api/publish`                          | 接收 CLI 推送(Bearer 鉴权) |
| `GET /docs`                                  | Swagger UI                 |

## 待补充(不在本次代码范围内)

- `apps/`:iOS/macOS 客户端,SwiftData 模型 + 同步逻辑 + CloudKit 用户数据

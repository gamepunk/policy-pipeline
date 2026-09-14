-- database/migrations/20260914000000_create_content_schema.sql
-- 权威内容库 schema。这份 .sql 同时喂给本地 SQLite(crawler/lib/store/database.rb 执行)
-- 和 Cloudflare D1(server/wrangler.jsonc 的 migrations_dir 直接复用本目录),避免两边 schema 手写不一致。

CREATE TABLE IF NOT EXISTS categories (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  title TEXT NOT NULL UNIQUE,
  description TEXT,
  created_at DATETIME NOT NULL,
  updated_at DATETIME NOT NULL
);

CREATE TABLE IF NOT EXISTS agings (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  title TEXT NOT NULL UNIQUE,
  description TEXT,
  created_at DATETIME NOT NULL,
  updated_at DATETIME NOT NULL
);

CREATE TABLE IF NOT EXISTS topics (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  title TEXT NOT NULL UNIQUE,
  description TEXT,
  created_at DATETIME NOT NULL,
  updated_at DATETIME NOT NULL
);

CREATE TABLE IF NOT EXISTS taxes (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  title TEXT NOT NULL UNIQUE,
  description TEXT,
  created_at DATETIME NOT NULL,
  updated_at DATETIME NOT NULL
);

CREATE TABLE IF NOT EXISTS industries (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  title TEXT NOT NULL UNIQUE,
  description TEXT,
  created_at DATETIME NOT NULL,
  updated_at DATETIME NOT NULL
);

CREATE TABLE IF NOT EXISTS tags (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  title TEXT NOT NULL UNIQUE,
  description TEXT,
  created_at DATETIME NOT NULL,
  updated_at DATETIME NOT NULL
);

CREATE TABLE IF NOT EXISTS collections (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  title TEXT NOT NULL UNIQUE,
  description TEXT,
  created_at DATETIME NOT NULL,
  updated_at DATETIME NOT NULL
);

-- 政策原文 / 政策解读,统一用 purpose 区分(0=policy 1=interpretation)
CREATE TABLE IF NOT EXISTS articles (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  code TEXT,
  origin_url TEXT,
  title TEXT,
  content TEXT,
  short_content TEXT,
  publisher TEXT,
  purpose INTEGER NOT NULL,
  doc_type TEXT,
  doc_year INTEGER,
  doc_no INTEGER,
  doc_number TEXT,
  notice TEXT,
  published_at DATETIME,
  category_id INTEGER REFERENCES categories(id),
  aging_id INTEGER REFERENCES agings(id),
  parent_article_id INTEGER REFERENCES articles(id),
  child_article_id INTEGER REFERENCES articles(id),

  content_hash TEXT,         -- 内容 hash,判断这次抓取内容是否有变化
  content_version INTEGER NOT NULL DEFAULT 0,  -- 0=尚未发布过;>0=最后一次发布时的全局版本号

  created_at DATETIME NOT NULL,
  updated_at DATETIME NOT NULL
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_articles_purpose_code_unique ON articles(purpose, code);
CREATE UNIQUE INDEX IF NOT EXISTS idx_articles_purpose_origin_url_unique ON articles(purpose, origin_url);
CREATE INDEX IF NOT EXISTS idx_articles_published_at ON articles(published_at);
CREATE INDEX IF NOT EXISTS idx_articles_content_version ON articles(content_version);
CREATE INDEX IF NOT EXISTS idx_articles_category_id ON articles(category_id);
CREATE INDEX IF NOT EXISTS idx_articles_aging_id ON articles(aging_id);

CREATE TABLE IF NOT EXISTS attachments (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  article_id INTEGER NOT NULL REFERENCES articles(id),
  title TEXT,
  description TEXT,
  file_type TEXT,
  source_url TEXT,
  created_at DATETIME NOT NULL,
  updated_at DATETIME NOT NULL
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_attachments_article_source_url_unique ON attachments(article_id, source_url);
CREATE INDEX IF NOT EXISTS idx_attachments_article_id ON attachments(article_id);

CREATE TABLE IF NOT EXISTS articles_topics (
  article_id INTEGER NOT NULL,
  topic_id INTEGER NOT NULL
);
CREATE UNIQUE INDEX IF NOT EXISTS idx_articles_topics_unique ON articles_topics(article_id, topic_id);
CREATE INDEX IF NOT EXISTS idx_articles_topics_topic ON articles_topics(topic_id, article_id);

CREATE TABLE IF NOT EXISTS articles_taxes (
  article_id INTEGER NOT NULL,
  tax_id INTEGER NOT NULL
);
CREATE UNIQUE INDEX IF NOT EXISTS idx_articles_taxes_unique ON articles_taxes(article_id, tax_id);
CREATE INDEX IF NOT EXISTS idx_articles_taxes_tax ON articles_taxes(tax_id, article_id);

CREATE TABLE IF NOT EXISTS articles_industries (
  article_id INTEGER NOT NULL,
  industry_id INTEGER NOT NULL
);
CREATE UNIQUE INDEX IF NOT EXISTS idx_articles_industries_unique ON articles_industries(article_id, industry_id);
CREATE INDEX IF NOT EXISTS idx_articles_industries_industry ON articles_industries(industry_id, article_id);

CREATE TABLE IF NOT EXISTS articles_tags (
  article_id INTEGER NOT NULL,
  tag_id INTEGER NOT NULL
);
CREATE UNIQUE INDEX IF NOT EXISTS idx_articles_tags_unique ON articles_tags(article_id, tag_id);
CREATE INDEX IF NOT EXISTS idx_articles_tags_tag ON articles_tags(tag_id, article_id);

CREATE TABLE IF NOT EXISTS articles_collections (
  article_id INTEGER NOT NULL,
  collection_id INTEGER NOT NULL,
  created_at DATETIME NOT NULL
);
CREATE UNIQUE INDEX IF NOT EXISTS idx_articles_collections_unique ON articles_collections(article_id, collection_id);

CREATE TABLE IF NOT EXISTS articles_related_articles (
  article_id INTEGER NOT NULL,
  related_article_id INTEGER NOT NULL
);
CREATE UNIQUE INDEX IF NOT EXISTS idx_related_articles_unique ON articles_related_articles(article_id, related_article_id);

-- key-value 元数据,目前只存 content_version(全局发布版本号)
CREATE TABLE IF NOT EXISTS meta (
  key TEXT PRIMARY KEY,
  value TEXT
);

INSERT OR IGNORE INTO meta (key, value) VALUES ('content_version', '0');

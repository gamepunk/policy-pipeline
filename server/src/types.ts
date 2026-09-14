// 数据契约:与 crawler 推送到 /api/publish 的 JSON 结构保持一致。
// PUSH_TOKEN 通过 `wrangler secret put PUSH_TOKEN` 注入,
// 与 crawler config/secrets 的 D1_PUSH_TOKEN 对应。

export interface Env {
  DB: D1Database;
  PUSH_TOKEN?: string;
}

export interface AttachmentPayload {
  title?: string | null;
  source_url?: string | null;
  file_type?: string | null;
}

export interface ArticlePayload {
  code?: string | null;
  origin_url?: string | null;
  title?: string | null;
  content?: string | null;
  short_content?: string | null;
  publisher?: string | null;
  purpose: number;
  doc_type?: string | null;
  doc_year?: number | null;
  doc_no?: number | null;
  doc_number?: string | null;
  notice?: string | null;
  published_at?: string | null;
  category?: string | null;
  aging?: string | null;
  parent_article_code?: string | null;
  child_article_code?: string | null;
  topics?: string[];
  taxes?: string[];
  industries?: string[];
  tags?: string[];
  attachments?: AttachmentPayload[];
  content_version?: number | null;
}

export interface PublishPayload {
  content_version: number;
  articles: ArticlePayload[];
}

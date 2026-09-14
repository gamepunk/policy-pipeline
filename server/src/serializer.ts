// 读库组装:把 articles 一行组装成客户端同步用的完整 JSON(含全部关联)。

import type { Env } from "./types";

export async function serialize_article(
  env: Env,
  row: Record<string, unknown>,
): Promise<Record<string, unknown>> {
  const id = row.id as number;

  const category = row.category_id
    ? await env.DB.prepare("SELECT title FROM categories WHERE id = ?")
        .bind(row.category_id as number)
        .first<{ title: string }>()
    : null;
  const aging = row.aging_id
    ? await env.DB.prepare("SELECT title FROM agings WHERE id = ?")
        .bind(row.aging_id as number)
        .first<{ title: string }>()
    : null;
  const parent = row.policy_id
    ? await env.DB.prepare("SELECT code FROM articles WHERE id = ?")
        .bind(row.policy_id as number)
        .first<{ code: string }>()
    : null;

  const topics = await env.DB.prepare(
    "SELECT t.title FROM topics t JOIN articles_topics jt ON jt.topic_id = t.id WHERE jt.article_id = ?",
  )
    .bind(id)
    .all<{ title: string }>();
  const industries = await env.DB.prepare(
    "SELECT t.title FROM industries t JOIN articles_industries jt ON jt.industry_id = t.id WHERE jt.article_id = ?",
  )
    .bind(id)
    .all<{ title: string }>();
  const attachments = await env.DB.prepare(
    "SELECT title, source_url, file_type FROM attachments WHERE article_id = ?",
  )
    .bind(id)
    .all<{
      title: string | null;
      source_url: string | null;
      file_type: string | null;
    }>();

  return {
    code: row.code,
    origin_url: row.origin_url,
    title: row.title,
    content: row.content,
    short_content: row.short_content,
    publisher: row.publisher,
    doc_type: row.doc_type,
    doc_year: row.doc_year,
    doc_no: row.doc_no,
    doc_number: row.doc_number,
    notice: row.notice,
    published_at: row.published_at,
    category: category?.title ?? null,
    aging: aging?.title ?? null,
    policy_code: parent?.code ?? null,
    topics: topics.results.map((t) => t.title),
    industries: industries.results.map((t) => t.title),
    attachments: attachments.results.map((a) => ({
      title: a.title,
      source_url: a.source_url,
      file_type: a.file_type,
    })),
    version: row.version,
  };
}

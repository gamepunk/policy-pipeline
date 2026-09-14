// D1 写库:文章 upsert、参考数据 find_or_create、多对多关联。
// 对应 crawler 的 database.rb + publishing 的职责。

import type { ArticlePayload, Env } from "./types";

export async function read_content_version(env: Env): Promise<number> {
  const row = await env.DB.prepare(
    "SELECT value FROM meta WHERE key = 'content_version'",
  ).first<{ value: string }>();
  return row ? parseInt(row.value, 10) || 0 : 0;
}

// 按 title 查找或创建参考数据(category/aging/topic/tax/industry/tag),返回 id。
// table 参数只允许代码内的固定枚举,不会接受用户输入。
export async function find_or_create_id(
  env: Env,
  table: string,
  title: string,
): Promise<number | null> {
  if (!title) return null;

  const existing = await env.DB.prepare(
    `SELECT id FROM ${table} WHERE title = ?`,
  )
    .bind(title)
    .first<{ id: number }>();
  if (existing) return existing.id;

  const now = new Date().toISOString();
  const result = await env.DB.prepare(
    `INSERT INTO ${table} (title, created_at, updated_at) VALUES (?, ?, ?)`,
  )
    .bind(title, now, now)
    .run();

  return result.meta.last_row_id as number;
}

export async function find_article_id_by_code(
  env: Env,
  code?: string | null,
): Promise<number | null> {
  if (!code) return null;
  const row = await env.DB.prepare("SELECT id FROM articles WHERE code = ?")
    .bind(code)
    .first<{ id: number }>();
  return row ? row.id : null;
}

export async function upsert_article(
  env: Env,
  a: ArticlePayload,
  version: number,
): Promise<void> {
  const now = new Date().toISOString();

  let existing: { id: number } | null = null;
  if (a.code) {
    existing = await env.DB.prepare(
      "SELECT id FROM articles WHERE purpose = ? AND code = ?",
    )
      .bind(a.purpose, a.code)
      .first<{ id: number }>();
  }
  if (!existing && a.origin_url) {
    existing = await env.DB.prepare(
      "SELECT id FROM articles WHERE purpose = ? AND origin_url = ?",
    )
      .bind(a.purpose, a.origin_url)
      .first<{ id: number }>();
  }

  const categoryId = await find_or_create_id(
    env,
    "categories",
    a.category || "",
  );
  const agingId = await find_or_create_id(env, "agings", a.aging || "");
  const parentId = await find_article_id_by_code(env, a.parent_article_code);
  const childId = await find_article_id_by_code(env, a.child_article_code);

  let articleId: number;
  if (existing) {
    articleId = existing.id;
    await env.DB.prepare(
      `
      UPDATE articles SET
        code = ?, origin_url = ?, title = ?, content = ?, short_content = ?,
        publisher = ?, purpose = ?, doc_type = ?, doc_year = ?, doc_no = ?,
        doc_number = ?, notice = ?, published_at = ?, category_id = ?, aging_id = ?,
        parent_article_id = ?, child_article_id = ?, content_version = ?, updated_at = ?
      WHERE id = ?
    `,
    )
      .bind(
        a.code ?? null,
        a.origin_url ?? null,
        a.title ?? null,
        a.content ?? null,
        a.short_content ?? null,
        a.publisher ?? null,
        a.purpose,
        a.doc_type ?? null,
        a.doc_year ?? null,
        a.doc_no ?? null,
        a.doc_number ?? null,
        a.notice ?? null,
        a.published_at ?? null,
        categoryId,
        agingId,
        parentId,
        childId,
        version,
        now,
        articleId,
      )
      .run();
  } else {
    const result = await env.DB.prepare(
      `
      INSERT INTO articles (
        code, origin_url, title, content, short_content, publisher, purpose,
        doc_type, doc_year, doc_no, doc_number, notice, published_at,
        category_id, aging_id, parent_article_id, child_article_id,
        content_version, created_at, updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    `,
    )
      .bind(
        a.code ?? null,
        a.origin_url ?? null,
        a.title ?? null,
        a.content ?? null,
        a.short_content ?? null,
        a.publisher ?? null,
        a.purpose,
        a.doc_type ?? null,
        a.doc_year ?? null,
        a.doc_no ?? null,
        a.doc_number ?? null,
        a.notice ?? null,
        a.published_at ?? null,
        categoryId,
        agingId,
        parentId,
        childId,
        version,
        now,
        now,
      )
      .run();
    articleId = result.meta.last_row_id as number;
  }

  await link_many(
    env,
    articleId,
    "articles_topics",
    "topic_id",
    "topics",
    a.topics,
  );
  await link_many(env, articleId, "articles_taxes", "tax_id", "taxes", a.taxes);
  await link_many(
    env,
    articleId,
    "articles_industries",
    "industry_id",
    "industries",
    a.industries,
  );
  await link_many(env, articleId, "articles_tags", "tag_id", "tags", a.tags);

  // attachments 全量重建,保证幂等
  await env.DB.prepare("DELETE FROM attachments WHERE article_id = ?")
    .bind(articleId)
    .run();
  for (const att of a.attachments || []) {
    if (!att || !att.source_url) continue;
    await env.DB.prepare(
      "INSERT INTO attachments (article_id, title, source_url, file_type, created_at, updated_at) " +
        "VALUES (?, ?, ?, ?, ?, ?)",
    )
      .bind(
        articleId,
        att.title ?? null,
        att.source_url,
        att.file_type ?? null,
        now,
        now,
      )
      .run();
  }
}

export async function link_many(
  env: Env,
  articleId: number,
  joinTable: string,
  idColumn: string,
  refTable: string,
  titles?: string[],
): Promise<void> {
  if (!titles || titles.length === 0) return;
  for (const title of titles) {
    const id = await find_or_create_id(env, refTable, title);
    if (id === null) continue;
    await env.DB.prepare(
      `INSERT OR IGNORE INTO ${joinTable} (article_id, ${idColumn}) VALUES (?, ?)`,
    )
      .bind(articleId, id)
      .run();
  }
}

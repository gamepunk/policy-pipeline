// 对外查询 API:列表、单篇、搜索、字典、统计。
// 只读接口,无需鉴权;返回给外部消费方(也可作为 web/客户端的数据源)。

import type { Env } from "./types";
import { read_version } from "./database";
import { serialize_article } from "./serializer";
import { json } from "./handlers";

// 列表/搜索用到的轻量摘要字段,不返回正文,减少响应体积。
function summarize(
  row: Record<string, unknown>,
  categoryTitle: string | null,
  agingTitle: string | null,
): Record<string, unknown> {
  return {
    id: row.id,
    code: row.code,
    title: row.title,
    doc_type: row.doc_type,
    doc_number: row.doc_number,
    published_at: row.published_at,
    version: row.version,
    category: categoryTitle,
    aging: agingTitle,
  };
}

const SUMMARY_SELECT = `
  SELECT a.*, c.title AS category_title, g.title AS aging_title
  FROM articles a
  LEFT JOIN categories c ON c.id = a.category_id
  LEFT JOIN agings g ON g.id = a.aging_id
`;

function parse_paging(url: URL): { page: number; limit: number } {
  const page = Math.max(
    parseInt(url.searchParams.get("page") || "1", 10) || 1,
    1,
  );
  const limit = Math.min(
    parseInt(url.searchParams.get("limit") || "20", 10) || 20,
    100,
  );
  return { page, limit };
}

// GET /api/content/articles?page=&limit=
export async function articles_list_handler(
  env: Env,
  url: URL,
): Promise<Response> {
  const { page, limit } = parse_paging(url);

  const totalRow = await env.DB.prepare(
    "SELECT count(*) AS c FROM articles",
  ).first<{ c: number }>();
  const total = totalRow?.c ?? 0;

  const { results: rows } = await env.DB.prepare(
    `${SUMMARY_SELECT} ORDER BY a.id DESC LIMIT ? OFFSET ?`,
  )
    .bind(limit, (page - 1) * limit)
    .all<Record<string, unknown>>();

  return json({
    total,
    page,
    limit,
    pages: Math.max(Math.ceil(total / limit), 1),
    articles: rows.map((r) =>
      summarize(
        r,
        (r.category_title as string) ?? null,
        (r.aging_title as string) ?? null,
      ),
    ),
  });
}

// GET /api/content/articles/:code —— 单篇完整 JSON(含全部关联)
export async function article_show_handler(
  env: Env,
  code: string,
): Promise<Response> {
  const row = await env.DB.prepare("SELECT * FROM articles WHERE code = ?")
    .bind(code)
    .first<Record<string, unknown>>();
  if (!row) {
    return json({ error: "not_found" }, 404);
  }
  return json(await serialize_article(env, row));
}

// GET /api/content/search?q=&page=&limit= —— 标题/文号/摘要模糊搜索
export async function search_handler(env: Env, url: URL): Promise<Response> {
  const q = (url.searchParams.get("q") || "").trim();
  if (!q) {
    return json({ error: "missing_q" }, 400);
  }
  const { page, limit } = parse_paging(url);
  const like = `%${q}%`;

  const where =
    "WHERE a.title LIKE ? OR a.code LIKE ? OR a.doc_number LIKE ? OR a.short_content LIKE ?";
  const params = [like, like, like, like];

  const totalRow = await env.DB.prepare(
    `SELECT count(*) AS c FROM articles a ${where}`,
  )
    .bind(...params)
    .first<{ c: number }>();
  const total = totalRow?.c ?? 0;

  const { results: rows } = await env.DB.prepare(
    `${SUMMARY_SELECT} ${where} ORDER BY a.id DESC LIMIT ? OFFSET ?`,
  )
    .bind(...params, limit, (page - 1) * limit)
    .all<Record<string, unknown>>();

  return json({
    q,
    total,
    page,
    limit,
    pages: Math.max(Math.ceil(total / limit), 1),
    articles: rows.map((r) =>
      summarize(
        r,
        (r.category_title as string) ?? null,
        (r.aging_title as string) ?? null,
      ),
    ),
  });
}

// GET /api/content/dictionaries —— 全部字典表
export async function dictionaries_handler(env: Env): Promise<Response> {
  const tables = ["categories", "agings", "topics", "industries"] as const;

  const out: Record<string, unknown> = {};
  for (const t of tables) {
    const { results } = await env.DB.prepare(
      `SELECT id, title, description FROM ${t} ORDER BY id ASC`,
    ).all<Record<string, unknown>>();
    out[t] = results;
  }
  return json(out);
}

// GET /api/content/stats —— 统计概览
export async function stats_handler(env: Env): Promise<Response> {
  const count = async (where: string) => {
    const row = await env.DB.prepare(
      `SELECT count(*) AS c FROM articles ${where}`,
    ).first<{ c: number }>();
    return row?.c ?? 0;
  };

  const [total, policy, interpretation, version] = await Promise.all([
    count(""),
    count(
      "WHERE category_id NOT IN (SELECT id FROM categories WHERE title = '文字政策解读')",
    ),
    count(
      "WHERE category_id IN (SELECT id FROM categories WHERE title = '文字政策解读')",
    ),
    read_version(env),
  ]);

  return json({
    version: version,
    total,
    policy,
    interpretation,
  });
}

// 接口处理:/api/content/version、/api/content/sync、/api/publish。
// 对应 crawler 的 commands 层职责。

import type { Env, PublishPayload } from "./types";
import { read_content_version, upsert_article } from "./database";
import { serialize_article } from "./serializer";

export function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "Content-Type": "application/json; charset=utf-8" },
  });
}

function authorized(request: Request, env: Env): boolean {
  const token = env.PUSH_TOKEN;
  if (!token) return false;

  const header = request.headers.get("Authorization") || "";
  const expected = `Bearer ${token}`;
  if (header.length !== expected.length) return false;

  // 简单 timing-safe 比较
  let diff = 0;
  for (let i = 0; i < header.length; i++) {
    diff |= header.charCodeAt(i) ^ expected.charCodeAt(i);
  }
  return diff === 0;
}

export async function version_handler(env: Env): Promise<Response> {
  return json({ content_version: await read_content_version(env) });
}

// 首版不做分页:增量同步场景下每次返回的数据量有限。
// 若未来数据量增大,再按 content_version + id 游标分页。
export async function sync_handler(env: Env, url: URL): Promise<Response> {
  const since = parseInt(url.searchParams.get("since") || "0", 10) || 0;
  const latest = await read_content_version(env);

  const { results: rows } = await env.DB.prepare(
    "SELECT * FROM articles WHERE content_version > ? ORDER BY content_version ASC, id ASC",
  )
    .bind(since)
    .all<Record<string, unknown>>();

  const articles: Record<string, unknown>[] = [];
  for (const row of rows) {
    articles.push(await serialize_article(env, row));
  }

  return json({ content_version: latest, articles });
}

export async function publish_handler(
  request: Request,
  env: Env,
): Promise<Response> {
  if (!authorized(request, env)) {
    return json({ error: "unauthorized" }, 401);
  }

  let payload: PublishPayload;
  try {
    payload = await request.json<PublishPayload>();
  } catch {
    return json({ error: "invalid_json" }, 400);
  }

  const version = payload?.content_version;
  if (!Number.isInteger(version) || !Array.isArray(payload.articles)) {
    return json({ error: "invalid_payload" }, 400);
  }

  for (const article of payload.articles) {
    await upsert_article(env, article, version);
  }

  await env.DB.prepare(
    "INSERT INTO meta (key, value) VALUES ('content_version', ?) " +
      "ON CONFLICT(key) DO UPDATE SET value = ?",
  )
    .bind(String(version), String(version))
    .run();

  return json({
    ok: true,
    content_version: version,
    count: payload.articles.length,
  });
}

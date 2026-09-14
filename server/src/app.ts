// 政策库内容同步 Worker 入口 + 路由分发。
//
// 接口:
//   POST /api/publish             接收 CLI 批量推送,upsert 到 D1(鉴权 Bearer PUSH_TOKEN)
//   GET  /api/content/version     返回当前全局 version
//   GET  /api/content/sync?since= 增量同步:返回 version > since 的文章及关联
//   GET  /docs                    Swagger UI 调试页
//   GET  /openapi.json            OpenAPI 规范
//
// schema 复用项目根 database/migrations/*.sql(wrangler.jsonc 的 migrations_dir),
// 与本地 SQLite 权威库保持一致。

import type { Env } from "./types";
import {
  json,
  publish_handler,
  sync_handler,
  version_handler,
} from "./handlers";
import { openapi_spec, swagger_html } from "./docs";
import {
  article_show_handler,
  articles_list_handler,
  dictionaries_handler,
  search_handler,
  stats_handler,
} from "./content";

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);

    if (url.pathname === "/docs" && request.method === "GET") {
      return new Response(swagger_html, {
        headers: { "Content-Type": "text/html; charset=utf-8" },
      });
    }

    if (url.pathname === "/openapi.json" && request.method === "GET") {
      return json(openapi_spec);
    }

    if (url.pathname === "/api/content/version" && request.method === "GET") {
      return version_handler(env);
    }

    if (url.pathname === "/api/content/sync" && request.method === "GET") {
      return sync_handler(env, url);
    }

    if (url.pathname === "/api/publish" && request.method === "POST") {
      return publish_handler(request, env);
    }

    // ---- 对外查询 API ----
    if (url.pathname === "/api/content/articles" && request.method === "GET") {
      return articles_list_handler(env, url);
    }

    if (url.pathname === "/api/content/search" && request.method === "GET") {
      return search_handler(env, url);
    }

    if (
      url.pathname === "/api/content/dictionaries" &&
      request.method === "GET"
    ) {
      return dictionaries_handler(env);
    }

    if (url.pathname === "/api/content/stats" && request.method === "GET") {
      return stats_handler(env);
    }

    const articleMatch = url.pathname.match(
      /^\/api\/content\/articles\/([^/]+)$/,
    );
    if (articleMatch && request.method === "GET") {
      return article_show_handler(env, decodeURIComponent(articleMatch[1]));
    }

    return json({ error: "not_found" }, 404);
  },
};

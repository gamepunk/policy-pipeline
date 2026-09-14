// API 调试文档:/openapi.json(OpenAPI 规范)+ /docs(Swagger UI 页面)。
// Swagger UI 从 CDN 加载,Worker 只返回 HTML 与 JSON,不打包任何依赖。

export const openapi_spec = {
  openapi: "3.0.0",
  info: {
    title: "政策库内容同步 API",
    description: "接收 crawler 批量推送,对外提供内容版本与增量同步",
    version: "1.0.0",
  },
  servers: [{ url: "/" }],
  paths: {
    "/api/content/version": {
      get: {
        summary: "当前全局内容版本号",
        responses: {
          200: {
            description: "OK",
            content: {
              "application/json": {
                schema: {
                  type: "object",
                  properties: { content_version: { type: "integer" } },
                },
              },
            },
          },
        },
      },
    },
    "/api/content/sync": {
      get: {
        summary: "增量同步(返回 content_version > since 的文章,游标分页)",
        parameters: [
          {
            name: "since",
            in: "query",
            description: "上次同步到的版本号,首次传 0",
            schema: { type: "integer", default: 0 },
          },
          {
            name: "after",
            in: "query",
            description: "游标:上一批返回的 next_after,首次传 0",
            schema: { type: "integer", default: 0 },
          },
          {
            name: "limit",
            in: "query",
            description: "每批条数,默认 200,最大 500",
            schema: { type: "integer", default: 200 },
          },
        ],
        responses: {
          200: {
            description: "OK",
            content: {
              "application/json": {
                schema: {
                  type: "object",
                  properties: {
                    content_version: { type: "integer" },
                    articles: { type: "array", items: { type: "object" } },
                    next_after: { type: "integer" },
                    has_more: { type: "boolean" },
                  },
                },
              },
            },
          },
        },
      },
    },
    "/api/publish": {
      post: {
        summary: "接收 crawler 批量推送(需 Bearer 鉴权)",
        security: [{ bearer_auth: [] }],
        requestBody: {
          required: true,
          content: {
            "application/json": {
              schema: {
                type: "object",
                required: ["content_version", "articles"],
                properties: {
                  content_version: { type: "integer" },
                  articles: { type: "array", items: { type: "object" } },
                },
              },
            },
          },
        },
        responses: {
          200: { description: "OK" },
          400: { description: "参数错误" },
          401: { description: "未授权(Bearer token 不符)" },
        },
      },
    },
  },
  components: {
    securitySchemes: {
      bearer_auth: { type: "http", scheme: "bearer" },
    },
  },
};

export const swagger_html = `<!DOCTYPE html>
<html lang="zh-CN">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>政策库内容同步 API</title>
  <link rel="stylesheet" href="https://unpkg.com/swagger-ui-dist@5/swagger-ui.css" />
</head>
<body>
  <div id="swagger-ui"></div>
  <script src="https://unpkg.com/swagger-ui-dist@5/swagger-ui-bundle.js"></script>
  <script>
    SwaggerUIBundle({
      url: "/openapi.json",
      dom_id: "#swagger-ui",
      deepLinking: true,
    });
  </script>
</body>
</html>`;

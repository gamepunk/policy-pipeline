-- database/migrations/002_seed_dictionaries.sql
-- 预置字典数据。各字典表 title 均有 UNIQUE 约束,INSERT OR IGNORE 保证幂等,
-- 本地 SQLite(db:migrate)与 Cloudflare D1(wrangler d1 migrations apply)共用本文件。

INSERT OR IGNORE INTO categories (title, description, created_at, updated_at) VALUES
  ('法律', '全国人大及其常委会制定的法律', datetime('now'), datetime('now')),
  ('行政法规', '国务院制定的行政法规', datetime('now'), datetime('now')),
  ('国务院文件', '国务院及办公厅发布的文件', datetime('now'), datetime('now')),
  ('税务部门规章', '税务部门发布的规章制度', datetime('now'), datetime('now')),
  ('财税文件', '财政税务联合文件', datetime('now'), datetime('now')),
  ('税务规范性文件', '税务执行与征管规范文件', datetime('now'), datetime('now')),
  ('其他文件', '无法归入上述分类的政策文件', datetime('now'), datetime('now')),
  ('工作通知', '税务执行类通知与工作安排', datetime('now'), datetime('now'));

INSERT OR IGNORE INTO topics (title, description, created_at, updated_at) VALUES
  ('税收政策', '税收制度和政策调整', datetime('now'), datetime('now')),
  ('社会保险费政策', '社保费征缴相关政策', datetime('now'), datetime('now')),
  ('税费征管', '征收管理与执行规范', datetime('now'), datetime('now')),
  ('其他', '补充类专题', datetime('now'), datetime('now'));

INSERT OR IGNORE INTO taxes (title, created_at, updated_at) VALUES
  ('增值税', datetime('now'), datetime('now')),
  ('消费税', datetime('now'), datetime('now')),
  ('企业所得税', datetime('now'), datetime('now')),
  ('个人所得税', datetime('now'), datetime('now')),
  ('资源税', datetime('now'), datetime('now')),
  ('城市维护建设税', datetime('now'), datetime('now')),
  ('房产税', datetime('now'), datetime('now')),
  ('印花税', datetime('now'), datetime('now')),
  ('城镇土地使用税', datetime('now'), datetime('now')),
  ('土地增值税', datetime('now'), datetime('now')),
  ('车船税', datetime('now'), datetime('now')),
  ('车辆购置税', datetime('now'), datetime('now')),
  ('烟叶税', datetime('now'), datetime('now')),
  ('耕地占用税', datetime('now'), datetime('now')),
  ('契税', datetime('now'), datetime('now')),
  ('环境保护税', datetime('now'), datetime('now')),
  ('进出口税收', datetime('now'), datetime('now'));

INSERT OR IGNORE INTO industries (title, created_at, updated_at) VALUES
  ('农林业', datetime('now'), datetime('now')),
  ('工业', datetime('now'), datetime('now')),
  ('服务业', datetime('now'), datetime('now')),
  ('金融业', datetime('now'), datetime('now')),
  ('房地产业', datetime('now'), datetime('now')),
  ('社会民生', datetime('now'), datetime('now')),
  ('科技创新', datetime('now'), datetime('now')),
  ('创业就业', datetime('now'), datetime('now')),
  ('绿色发展', datetime('now'), datetime('now')),
  ('区域发展', datetime('now'), datetime('now')),
  ('涉外', datetime('now'), datetime('now'));

INSERT OR IGNORE INTO agings (title, description, created_at, updated_at) VALUES
  ('全文有效', '当前政策全文仍有效', datetime('now'), datetime('now')),
  ('已修改', '政策部分条款已被修订', datetime('now'), datetime('now')),
  ('全文失效', '政策已失效,不再执行', datetime('now'), datetime('now')),
  ('全文废止', '政策明确废止', datetime('now'), datetime('now'));

INSERT OR IGNORE INTO tags (title, created_at, updated_at) VALUES
  ('增值税', datetime('now'), datetime('now')),
  ('企业所得税', datetime('now'), datetime('now')),
  ('个人所得税', datetime('now'), datetime('now')),
  ('税收优惠', datetime('now'), datetime('now')),
  ('征管规范', datetime('now'), datetime('now')),
  ('智能办税', datetime('now'), datetime('now'));

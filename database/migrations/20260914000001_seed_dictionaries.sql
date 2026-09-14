-- database/migrations/002_seed_dictionaries.sql
-- 预置字典数据。各字典表 title 均有 UNIQUE 约束,INSERT OR IGNORE 保证幂等,
-- 本地 SQLite(db:migrate)与 Cloudflare D1(wrangler d1 migrations apply)共用本文件。

INSERT OR IGNORE INTO categories (title, description, parent_id, created_at, updated_at) VALUES
  ('法律', '全国人大及其常委会制定的法律', NULL, datetime('now'), datetime('now')),
  ('行政法规', '国务院制定的行政法规', NULL, datetime('now'), datetime('now')),
  ('国务院文件', '国务院及办公厅发布的文件', NULL, datetime('now'), datetime('now')),
  ('税务部门规章', '税务部门发布的规章制度', NULL, datetime('now'), datetime('now')),
  ('财税文件', '财政税务联合文件', NULL, datetime('now'), datetime('now')),
  ('税务规范性文件', '税务执行与征管规范文件', NULL, datetime('now'), datetime('now')),
  ('其他文件', '无法归入上述分类的政策文件', NULL, datetime('now'), datetime('now')),
  ('工作通知', '税务执行类通知与工作安排', NULL, datetime('now'), datetime('now')),
  ('政策指引', '政策指引类文件', NULL, datetime('now'), datetime('now')),
  ('政策解读', '政策解读大类', NULL, datetime('now'), datetime('now'));

INSERT OR IGNORE INTO categories (title, description, parent_id, created_at, updated_at)
SELECT '文字政策解读', '文字政策解读文章', id, datetime('now'), datetime('now') FROM categories WHERE title = '政策解读';
INSERT OR IGNORE INTO categories (title, description, parent_id, created_at, updated_at)
SELECT '图片政策解读', '一图读懂类解读', id, datetime('now'), datetime('now') FROM categories WHERE title = '政策解读';
INSERT OR IGNORE INTO categories (title, description, parent_id, created_at, updated_at)
SELECT '视频政策解读', '视频类解读', id, datetime('now'), datetime('now') FROM categories WHERE title = '政策解读';
INSERT OR IGNORE INTO categories (title, description, parent_id, created_at, updated_at)
SELECT '普法', '普法栏目', id, datetime('now'), datetime('now') FROM categories WHERE title = '视频政策解读';
INSERT OR IGNORE INTO categories (title, description, parent_id, created_at, updated_at)
SELECT '税问我答', '税问我答栏目', id, datetime('now'), datetime('now') FROM categories WHERE title = '视频政策解读';
INSERT OR IGNORE INTO categories (title, description, parent_id, created_at, updated_at)
SELECT '秒懂政策', '秒懂政策栏目', id, datetime('now'), datetime('now') FROM categories WHERE title = '视频政策解读';
INSERT OR IGNORE INTO categories (title, description, parent_id, created_at, updated_at)
SELECT '办税便利贴', '办税便利贴栏目', id, datetime('now'), datetime('now') FROM categories WHERE title = '视频政策解读';
INSERT OR IGNORE INTO categories (title, description, parent_id, created_at, updated_at)
SELECT '税务讲堂', '税务讲堂栏目', id, datetime('now'), datetime('now') FROM categories WHERE title = '视频政策解读';
INSERT OR IGNORE INTO categories (title, description, parent_id, created_at, updated_at)
SELECT '其他', '其他解读栏目', id, datetime('now'), datetime('now') FROM categories WHERE title = '视频政策解读';
INSERT OR IGNORE INTO categories (title, description, parent_id, created_at, updated_at)
SELECT '税法小课堂', '税法小课堂栏目', id, datetime('now'), datetime('now') FROM categories WHERE title = '普法';
INSERT OR IGNORE INTO categories (title, description, parent_id, created_at, updated_at)
SELECT '数字人播报', '数字人播报栏目', id, datetime('now'), datetime('now') FROM categories WHERE title = '普法';
INSERT OR IGNORE INTO categories (title, description, parent_id, created_at, updated_at)
SELECT '@中国税务有回应', '@中国税务有回应栏目', id, datetime('now'), datetime('now') FROM categories WHERE title = '视频政策解读';
INSERT OR IGNORE INTO categories (title, description, parent_id, created_at, updated_at)
SELECT '税费政策我来讲', '税费政策我来讲栏目', id, datetime('now'), datetime('now') FROM categories WHERE title = '视频政策解读';
INSERT OR IGNORE INTO categories (title, description, parent_id, created_at, updated_at)
SELECT '合规纳税小课堂', '合规纳税小课堂栏目', id, datetime('now'), datetime('now') FROM categories WHERE title = '视频政策解读';

INSERT OR IGNORE INTO topics (title, description, parent_id, created_at, updated_at) VALUES
  ('税收政策', '税收制度和政策调整', NULL, datetime('now'), datetime('now')),
  ('社会保险费政策', '社保费征缴相关政策', NULL, datetime('now'), datetime('now')),
  ('税费征管', '征收管理与执行规范', NULL, datetime('now'), datetime('now')),
  ('非税收入政策', '非税收入相关政策', NULL, datetime('now'), datetime('now')),
  ('其他', '补充类专题', NULL, datetime('now'), datetime('now'));

-- 税收政策子类(税种)
INSERT OR IGNORE INTO topics (title, description, parent_id, created_at, updated_at)
SELECT '增值税', '对商品和服务增值额征收的流转税', id, datetime('now'), datetime('now') FROM topics WHERE title = '税收政策';
INSERT OR IGNORE INTO topics (title, description, parent_id, created_at, updated_at)
SELECT '消费税', '对特定消费品征收的税', id, datetime('now'), datetime('now') FROM topics WHERE title = '税收政策';
INSERT OR IGNORE INTO topics (title, description, parent_id, created_at, updated_at)
SELECT '企业所得税', '对企业生产经营所得征收的所得税', id, datetime('now'), datetime('now') FROM topics WHERE title = '税收政策';
INSERT OR IGNORE INTO topics (title, description, parent_id, created_at, updated_at)
SELECT '个人所得税', '对个人各项所得征收的所得税', id, datetime('now'), datetime('now') FROM topics WHERE title = '税收政策';
INSERT OR IGNORE INTO topics (title, description, parent_id, created_at, updated_at)
SELECT '资源税', '对开采应税矿产品和生产盐征收的税', id, datetime('now'), datetime('now') FROM topics WHERE title = '税收政策';
INSERT OR IGNORE INTO topics (title, description, parent_id, created_at, updated_at)
SELECT '城市维护建设税', '以增值税、消费税税额为计税依据的附加税', id, datetime('now'), datetime('now') FROM topics WHERE title = '税收政策';
INSERT OR IGNORE INTO topics (title, description, parent_id, created_at, updated_at)
SELECT '房产税', '以房屋为征税对象征收的财产税', id, datetime('now'), datetime('now') FROM topics WHERE title = '税收政策';
INSERT OR IGNORE INTO topics (title, description, parent_id, created_at, updated_at)
SELECT '印花税', '对书立、领受应税凭证的行为征收的税', id, datetime('now'), datetime('now') FROM topics WHERE title = '税收政策';
INSERT OR IGNORE INTO topics (title, description, parent_id, created_at, updated_at)
SELECT '城镇土地使用税', '对使用城镇土地征收的税', id, datetime('now'), datetime('now') FROM topics WHERE title = '税收政策';
INSERT OR IGNORE INTO topics (title, description, parent_id, created_at, updated_at)
SELECT '土地增值税', '对转让国有土地使用权及地上建筑物取得增值额征收的税', id, datetime('now'), datetime('now') FROM topics WHERE title = '税收政策';
INSERT OR IGNORE INTO topics (title, description, parent_id, created_at, updated_at)
SELECT '车船税', '对车辆、船舶征收的财产税', id, datetime('now'), datetime('now') FROM topics WHERE title = '税收政策';
INSERT OR IGNORE INTO topics (title, description, parent_id, created_at, updated_at)
SELECT '车辆购置税', '对购置应税车辆征收的税', id, datetime('now'), datetime('now') FROM topics WHERE title = '税收政策';
INSERT OR IGNORE INTO topics (title, description, parent_id, created_at, updated_at)
SELECT '烟叶税', '对收购烟叶征收的税', id, datetime('now'), datetime('now') FROM topics WHERE title = '税收政策';
INSERT OR IGNORE INTO topics (title, description, parent_id, created_at, updated_at)
SELECT '耕地占用税', '对占用耕地征收的税', id, datetime('now'), datetime('now') FROM topics WHERE title = '税收政策';
INSERT OR IGNORE INTO topics (title, description, parent_id, created_at, updated_at)
SELECT '契税', '对土地、房屋权属转移征收的税', id, datetime('now'), datetime('now') FROM topics WHERE title = '税收政策';
INSERT OR IGNORE INTO topics (title, description, parent_id, created_at, updated_at)
SELECT '环境保护税', '对排放应税污染物征收的税', id, datetime('now'), datetime('now') FROM topics WHERE title = '税收政策';
INSERT OR IGNORE INTO topics (title, description, parent_id, created_at, updated_at)
SELECT '进出口税收', '进出口环节征收的关税、增值税、消费税等', id, datetime('now'), datetime('now') FROM topics WHERE title = '税收政策';
INSERT OR IGNORE INTO topics (title, description, parent_id, created_at, updated_at)
SELECT '国际税收', '跨境交易、税收协定、反避税等国际税收事项', id, datetime('now'), datetime('now') FROM topics WHERE title = '税收政策';
INSERT OR IGNORE INTO topics (title, description, parent_id, created_at, updated_at)
SELECT '营业税', '对提供应税劳务、转让无形资产或销售不动产征收的流转税(已改征增值税)', id, datetime('now'), datetime('now') FROM topics WHERE title = '税收政策';
INSERT OR IGNORE INTO topics (title, description, parent_id, created_at, updated_at)
SELECT '水资源税', '对直接取用地表水、地下水征收的税', id, datetime('now'), datetime('now') FROM topics WHERE title = '税收政策';
INSERT OR IGNORE INTO topics (title, description, parent_id, created_at, updated_at)
SELECT '其他税收政策', '其他未归类的税收政策', id, datetime('now'), datetime('now') FROM topics WHERE title = '税收政策';

-- 社会保险费政策子类(社保费)
INSERT OR IGNORE INTO topics (title, description, parent_id, created_at, updated_at)
SELECT '失业保险费', '为保障失业人员基本生活征缴的社会保险费', id, datetime('now'), datetime('now') FROM topics WHERE title = '社会保险费政策';
INSERT OR IGNORE INTO topics (title, description, parent_id, created_at, updated_at)
SELECT '工伤保险费', '为保障职工工伤待遇征缴的社会保险费', id, datetime('now'), datetime('now') FROM topics WHERE title = '社会保险费政策';
INSERT OR IGNORE INTO topics (title, description, parent_id, created_at, updated_at)
SELECT '基本养老保险费', '为保障职工退休后基本生活征缴的社会保险费', id, datetime('now'), datetime('now') FROM topics WHERE title = '社会保险费政策';
INSERT OR IGNORE INTO topics (title, description, parent_id, created_at, updated_at)
SELECT '基本医疗保险费', '为保障职工基本医疗待遇征缴的社会保险费', id, datetime('now'), datetime('now') FROM topics WHERE title = '社会保险费政策';
INSERT OR IGNORE INTO topics (title, description, parent_id, created_at, updated_at)
SELECT '生育保险费', '为保障职工生育待遇征缴的社会保险费', id, datetime('now'), datetime('now') FROM topics WHERE title = '社会保险费政策';
INSERT OR IGNORE INTO topics (title, description, parent_id, created_at, updated_at)
SELECT '残疾人就业保障金', '为促进残疾人就业征缴的保障金', id, datetime('now'), datetime('now') FROM topics WHERE title = '社会保险费政策';
INSERT OR IGNORE INTO topics (title, description, parent_id, created_at, updated_at)
SELECT '职业伤害保障费', '为保障新就业形态劳动者职业伤害待遇征缴的费用', id, datetime('now'), datetime('now') FROM topics WHERE title = '社会保险费政策';
INSERT OR IGNORE INTO topics (title, description, parent_id, created_at, updated_at)
SELECT '其他社会保险费', '其他社会保险费', id, datetime('now'), datetime('now') FROM topics WHERE title = '社会保险费政策';

-- 非税收入政策子类(费种/基金)
INSERT OR IGNORE INTO topics (title, description, parent_id, created_at, updated_at)
SELECT '教育附加费', '以增值税、消费税税额为计征依据的教育费附加', id, datetime('now'), datetime('now') FROM topics WHERE title = '非税收入政策';
INSERT OR IGNORE INTO topics (title, description, parent_id, created_at, updated_at)
SELECT '地方教育费附加', '以增值税、消费税税额为计征依据的地方教育附加', id, datetime('now'), datetime('now') FROM topics WHERE title = '非税收入政策';
INSERT OR IGNORE INTO topics (title, description, parent_id, created_at, updated_at)
SELECT '文化事业建设费', '对广告业和娱乐业征收的政府性基金', id, datetime('now'), datetime('now') FROM topics WHERE title = '非税收入政策';
INSERT OR IGNORE INTO topics (title, description, parent_id, created_at, updated_at)
SELECT '矿产资源专项收入', '矿产资源相关专项收入', id, datetime('now'), datetime('now') FROM topics WHERE title = '非税收入政策';
INSERT OR IGNORE INTO topics (title, description, parent_id, created_at, updated_at)
SELECT '国有土地使用权出让收入', '国有土地使用权出让相关收入', id, datetime('now'), datetime('now') FROM topics WHERE title = '非税收入政策';
INSERT OR IGNORE INTO topics (title, description, parent_id, created_at, updated_at)
SELECT '国家重大水利工程建设基金', '支持国家重大水利工程建设的政府性基金', id, datetime('now'), datetime('now') FROM topics WHERE title = '非税收入政策';
INSERT OR IGNORE INTO topics (title, description, parent_id, created_at, updated_at)
SELECT '防空地下室易地建设费', '无法就地建设防空地下室时缴纳的易地建设费', id, datetime('now'), datetime('now') FROM topics WHERE title = '非税收入政策';
INSERT OR IGNORE INTO topics (title, description, parent_id, created_at, updated_at)
SELECT '城镇垃圾处理费', '城镇垃圾处理相关费用', id, datetime('now'), datetime('now') FROM topics WHERE title = '非税收入政策';
INSERT OR IGNORE INTO topics (title, description, parent_id, created_at, updated_at)
SELECT '大中型水库移民后期扶持基金', '大中型水库移民后期扶持相关基金', id, datetime('now'), datetime('now') FROM topics WHERE title = '非税收入政策';
INSERT OR IGNORE INTO topics (title, description, parent_id, created_at, updated_at)
SELECT '废弃电器电子产品处理基金', '废弃电器电子产品回收处理基金', id, datetime('now'), datetime('now') FROM topics WHERE title = '非税收入政策';
INSERT OR IGNORE INTO topics (title, description, parent_id, created_at, updated_at)
SELECT '石油特别收益金', '石油特别收益相关收入', id, datetime('now'), datetime('now') FROM topics WHERE title = '非税收入政策';
INSERT OR IGNORE INTO topics (title, description, parent_id, created_at, updated_at)
SELECT '土地闲置费', '对闲置土地征收的费用', id, datetime('now'), datetime('now') FROM topics WHERE title = '非税收入政策';
INSERT OR IGNORE INTO topics (title, description, parent_id, created_at, updated_at)
SELECT '海域使用金', '海域使用相关收入', id, datetime('now'), datetime('now') FROM topics WHERE title = '非税收入政策';
INSERT OR IGNORE INTO topics (title, description, parent_id, created_at, updated_at)
SELECT '水利建设基金', '水利建设相关政府性基金', id, datetime('now'), datetime('now') FROM topics WHERE title = '非税收入政策';
INSERT OR IGNORE INTO topics (title, description, parent_id, created_at, updated_at)
SELECT '免税商品特许经营收入', '免税商品特许经营相关收入', id, datetime('now'), datetime('now') FROM topics WHERE title = '非税收入政策';
INSERT OR IGNORE INTO topics (title, description, parent_id, created_at, updated_at)
SELECT '免税商品特许经营费', '免税商品特许经营相关费用', id, datetime('now'), datetime('now') FROM topics WHERE title = '非税收入政策';
INSERT OR IGNORE INTO topics (title, description, parent_id, created_at, updated_at)
SELECT '无居民海岛使用金', '无居民海岛使用相关收入', id, datetime('now'), datetime('now') FROM topics WHERE title = '非税收入政策';
INSERT OR IGNORE INTO topics (title, description, parent_id, created_at, updated_at)
SELECT '水土保持补偿费', '水土保持补偿相关费用', id, datetime('now'), datetime('now') FROM topics WHERE title = '非税收入政策';
INSERT OR IGNORE INTO topics (title, description, parent_id, created_at, updated_at)
SELECT '农网还贷资金', '农网还贷相关资金', id, datetime('now'), datetime('now') FROM topics WHERE title = '非税收入政策';
INSERT OR IGNORE INTO topics (title, description, parent_id, created_at, updated_at)
SELECT '可再生能源发展基金', '可再生能源发展相关基金', id, datetime('now'), datetime('now') FROM topics WHERE title = '非税收入政策';
INSERT OR IGNORE INTO topics (title, description, parent_id, created_at, updated_at)
SELECT '可再生能源电价附加', '可再生能源电价附加收入', id, datetime('now'), datetime('now') FROM topics WHERE title = '非税收入政策';
INSERT OR IGNORE INTO topics (title, description, parent_id, created_at, updated_at)
SELECT '油价调控风险准备金', '油价调控风险准备金', id, datetime('now'), datetime('now') FROM topics WHERE title = '非税收入政策';
INSERT OR IGNORE INTO topics (title, description, parent_id, created_at, updated_at)
SELECT '排污权出让收入', '排污权出让相关收入', id, datetime('now'), datetime('now') FROM topics WHERE title = '非税收入政策';
INSERT OR IGNORE INTO topics (title, description, parent_id, created_at, updated_at)
SELECT '中央水库移民扶持基金', '中央水库移民扶持相关基金', id, datetime('now'), datetime('now') FROM topics WHERE title = '非税收入政策';
INSERT OR IGNORE INTO topics (title, description, parent_id, created_at, updated_at)
SELECT '地方水库移民扶持基金', '地方水库移民扶持相关基金', id, datetime('now'), datetime('now') FROM topics WHERE title = '非税收入政策';
INSERT OR IGNORE INTO topics (title, description, parent_id, created_at, updated_at)
SELECT '三峡电站水资源费', '三峡电站水资源相关费用', id, datetime('now'), datetime('now') FROM topics WHERE title = '非税收入政策';
INSERT OR IGNORE INTO topics (title, description, parent_id, created_at, updated_at)
SELECT '（场外）核事故应急准备专项收入', '（场外）核事故应急准备专项收入', id, datetime('now'), datetime('now') FROM topics WHERE title = '非税收入政策';
INSERT OR IGNORE INTO topics (title, description, parent_id, created_at, updated_at)
SELECT '核电站乏燃料处理处置基金', '核电站乏燃料处理处置相关基金', id, datetime('now'), datetime('now') FROM topics WHERE title = '非税收入政策';
INSERT OR IGNORE INTO topics (title, description, parent_id, created_at, updated_at)
SELECT '核事故应急准备专项收入', '核事故应急准备专项收入', id, datetime('now'), datetime('now') FROM topics WHERE title = '非税收入政策';
INSERT OR IGNORE INTO topics (title, description, parent_id, created_at, updated_at)
SELECT '国家留成油收入', '国家留成油相关收入', id, datetime('now'), datetime('now') FROM topics WHERE title = '非税收入政策';
INSERT OR IGNORE INTO topics (title, description, parent_id, created_at, updated_at)
SELECT '其他非税收入政策', '其他非税收入政策', id, datetime('now'), datetime('now') FROM topics WHERE title = '非税收入政策';

INSERT OR IGNORE INTO industries (title, description, created_at, updated_at) VALUES
  ('农林业', '农业、林业、牧业、渔业等第一产业', datetime('now'), datetime('now')),
  ('工业', '制造业、采矿业、电力燃气等第二产业', datetime('now'), datetime('now')),
  ('服务业', '批发零售、住宿餐饮、交通运输等第三产业', datetime('now'), datetime('now')),
  ('金融业', '银行、保险、证券、基金等金融行业', datetime('now'), datetime('now')),
  ('房地产业', '房地产开发、经营、租赁及物业管理', datetime('now'), datetime('now')),
  ('社会民生', '教育、医疗、养老、住房等民生领域', datetime('now'), datetime('now')),
  ('科技创新', '高新技术、研发投入、科技成果转化', datetime('now'), datetime('now')),
  ('创业就业', '创业扶持、就业促进、人才引进', datetime('now'), datetime('now')),
  ('绿色发展', '节能环保、清洁能源、绿色低碳', datetime('now'), datetime('now')),
  ('区域发展', '区域协调、特殊经济区域、乡村振兴', datetime('now'), datetime('now')),
  ('涉外', '外资、进出口贸易、跨境投资', datetime('now'), datetime('now'));

INSERT OR IGNORE INTO agings (title, description, created_at, updated_at) VALUES
  ('全文有效', '当前政策全文仍有效', datetime('now'), datetime('now')),
  ('已修改', '政策部分条款已被修订', datetime('now'), datetime('now')),
  ('全文失效', '政策已失效,不再执行', datetime('now'), datetime('now')),
  ('全文废止', '政策明确废止', datetime('now'), datetime('now'));

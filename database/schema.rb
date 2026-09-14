# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_09_14_000001) do
  create_table "agings", force: :cascade do |t|
    t.datetime "created_at", precision: nil, null: false
    t.text "description"
    t.text "title", null: false
    t.datetime "updated_at", precision: nil, null: false
  end

  create_table "articles", force: :cascade do |t|
    t.integer "aging_id"
    t.integer "category_id"
    t.text "code"
    t.text "content"
    t.text "content_hash"
    t.datetime "created_at", precision: nil, null: false
    t.integer "doc_no"
    t.text "doc_number"
    t.text "doc_type"
    t.integer "doc_year"
    t.text "notice"
    t.text "origin_url"
    t.integer "policy_id"
    t.datetime "published_at", precision: nil
    t.text "publisher"
    t.text "short_content"
    t.text "title"
    t.datetime "updated_at", precision: nil, null: false
    t.integer "version", default: 0, null: false
    t.index ["aging_id"], name: "idx_articles_aging_id"
    t.index ["category_id"], name: "idx_articles_category_id"
    t.index ["code"], name: "idx_articles_code_unique", unique: true
    t.index ["origin_url"], name: "idx_articles_origin_url_unique", unique: true
    t.index ["published_at"], name: "idx_articles_published_at"
    t.index ["version"], name: "idx_articles_version"
  end

  create_table "articles_industries", id: false, force: :cascade do |t|
    t.integer "article_id", null: false
    t.integer "industry_id", null: false
    t.index ["article_id", "industry_id"], name: "idx_articles_industries_unique", unique: true
    t.index ["industry_id", "article_id"], name: "idx_articles_industries_industry"
  end

  create_table "articles_related_articles", id: false, force: :cascade do |t|
    t.integer "article_id", null: false
    t.integer "related_article_id", null: false
    t.index ["article_id", "related_article_id"], name: "idx_related_articles_unique", unique: true
  end

  create_table "articles_topics", id: false, force: :cascade do |t|
    t.integer "article_id", null: false
    t.integer "topic_id", null: false
    t.index ["article_id", "topic_id"], name: "idx_articles_topics_unique", unique: true
    t.index ["topic_id", "article_id"], name: "idx_articles_topics_topic"
  end

  create_table "attachments", force: :cascade do |t|
    t.integer "article_id", null: false
    t.datetime "created_at", precision: nil, null: false
    t.text "description"
    t.text "file_type"
    t.text "source_url"
    t.text "title"
    t.datetime "updated_at", precision: nil, null: false
    t.index ["article_id", "source_url"], name: "idx_attachments_article_source_url_unique", unique: true
    t.index ["article_id"], name: "idx_attachments_article_id"
  end

  create_table "categories", force: :cascade do |t|
    t.datetime "created_at", precision: nil, null: false
    t.text "description"
    t.integer "parent_id"
    t.text "title", null: false
    t.datetime "updated_at", precision: nil, null: false
  end

  create_table "industries", force: :cascade do |t|
    t.datetime "created_at", precision: nil, null: false
    t.text "description"
    t.text "title", null: false
    t.datetime "updated_at", precision: nil, null: false
  end

  create_table "meta", primary_key: "key", id: :text, force: :cascade do |t|
    t.text "value"
  end

  create_table "topics", force: :cascade do |t|
    t.datetime "created_at", precision: nil, null: false
    t.text "description"
    t.integer "parent_id"
    t.text "title", null: false
    t.datetime "updated_at", precision: nil, null: false
  end

  add_foreign_key "articles", "agings"
  add_foreign_key "articles", "articles", column: "policy_id"
  add_foreign_key "articles", "categories"
  add_foreign_key "attachments", "articles"
  add_foreign_key "categories", "categories", column: "parent_id"
  add_foreign_key "topics", "topics", column: "parent_id"
end

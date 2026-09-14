# frozen_string_literal: true

require "test_helper"

class ArticleTest < Minitest::Test
  include TransactionalTestCase

  def test_interpretation_predicates
    interp_category = Category.find_by(title: "文字政策解读")
    policy_category = Category.find_by(title: "法律")

    policy = Article.create!(category: policy_category, title: "t1")
    interpretation = Article.create!(category: interp_category, title: "t2")

    assert policy.policy?
    refute policy.interpretation?
    assert interpretation.interpretation?
  end

  def test_mark_dirty_resets_version
    article = Article.create!(title: "t", version: 5)
    article.mark_dirty!
    assert_equal 0, article.reload.version
  end

  def test_pending_publish_scope
    Article.create!(title: "a", version: 0)
    Article.create!(title: "b", version: 3)
    assert_equal 1, Article.pending_publish.count
  end

  def test_habtm_topics
    article = Article.create!(title: "t")
    topic = Topic.create!(title: "topic1")

    article.topics << topic

    assert_equal 1, article.topics.count
    assert_equal [article.id], topic.articles.map(&:id)
  end

  def test_blank_fields_normalize_to_nil
    article = Article.create!(
      title: "t",
      publisher: "   ",
      doc_number: "   ",
      notice: ""
    )

    assert_nil article.publisher
    assert_nil article.doc_number
    assert_nil article.notice
  end
end

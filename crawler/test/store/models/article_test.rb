# frozen_string_literal: true

require "test_helper"

class ArticleTest < Minitest::Test
  include TransactionalTestCase

  def test_enum_predicates
    policy = Article.create!(purpose: :policy, title: "t1")
    interpretation = Article.create!(purpose: :interpretation, title: "t2")

    assert policy.policy?
    refute policy.interpretation?
    assert interpretation.interpretation?
  end

  def test_purpose_validation
    article = Article.new(title: "t")
    refute article.valid?
    assert_includes article.errors[:purpose], "can't be blank"
  end

  def test_mark_dirty_resets_content_version
    article = Article.create!(purpose: :policy, title: "t", content_version: 5)
    article.mark_dirty!
    assert_equal 0, article.reload.content_version
  end

  def test_pending_publish_scope
    Article.create!(purpose: :policy, title: "a", content_version: 0)
    Article.create!(purpose: :policy, title: "b", content_version: 3)
    assert_equal 1, Article.pending_publish.count
  end

  def test_habtm_topics
    article = Article.create!(purpose: :policy, title: "t")
    topic = Topic.create!(title: "topic1")

    article.topics << topic

    assert_equal 1, article.topics.count
    assert_equal [article.id], topic.articles.map(&:id)
  end
end

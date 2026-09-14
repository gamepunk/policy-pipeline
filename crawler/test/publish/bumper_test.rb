# frozen_string_literal: true

require "test_helper"

class BumperTest < Minitest::Test
  include TransactionalTestCase

  def test_bump_marks_only_pending_records
    pending = Article.create!(purpose: :policy, title: "pending")
    published = Article.create!(purpose: :policy, title: "published", content_version: 9)

    result = Publish::Bumper.bump!

    assert_equal 1, result[:count]
    assert_equal 1, result[:version]
    assert_equal 1, pending.reload.content_version
    assert_equal 9, published.reload.content_version
    assert_equal 1, Meta.content_version
  end

  def test_bump_with_no_pending_keeps_version
    Article.create!(purpose: :policy, title: "a", content_version: 3)
    Meta.set("content_version", 3)

    result = Publish::Bumper.bump!

    assert_equal 0, result[:count]
    assert_equal 3, result[:version]
  end
end

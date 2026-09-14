# frozen_string_literal: true

require "test_helper"

class BumperTest < Minitest::Test
  include TransactionalTestCase

  def test_bump_marks_only_pending_records
    pending = Article.create!(title: "pending")
    published = Article.create!(title: "published", version: 9)

    result = Publish::Bumper.bump!

    assert_equal 1, result[:count]
    assert_equal 1, result[:version]
    assert_equal 1, pending.reload.version
    assert_equal 9, published.reload.version
    assert_equal 1, Meta.version
  end

  def test_bump_with_no_pending_keeps_version
    Article.create!(title: "a", version: 3)
    Meta.set("version", 3)

    result = Publish::Bumper.bump!

    assert_equal 0, result[:count]
    assert_equal 3, result[:version]
  end
end

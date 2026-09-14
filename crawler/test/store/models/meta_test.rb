# frozen_string_literal: true

require "test_helper"

class MetaTest < Minitest::Test
  include TransactionalTestCase

  def test_content_version_default_is_zero
    assert_equal 0, Meta.content_version
  end

  def test_set_and_get
    Meta.set("content_version", 42)
    assert_equal 42, Meta.content_version
    assert_equal "42", Meta.get("content_version")
  end
end

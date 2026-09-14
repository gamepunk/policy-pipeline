# frozen_string_literal: true

require "test_helper"

class MetaTest < Minitest::Test
  include TransactionalTestCase

  def test_version_default_is_zero
    assert_equal 0, Meta.version
  end

  def test_set_and_get
    Meta.set("version", 42)
    assert_equal 42, Meta.version
    assert_equal "42", Meta.get("version")
  end
end

# frozen_string_literal: true

require "test_helper"

class ClockTest < Minitest::Test
  def test_parse_valid_datetime
    t = Clock.parse("2024-01-15 10:30:00")
    assert_equal 2024, t.year
    assert_equal 1, t.month
    assert_equal 15, t.day
  end

  def test_parse_nil
    assert_nil Clock.parse(nil)
  end

  def test_parse_blank
    assert_nil Clock.parse("   ")
  end

  def test_parse_invalid_returns_nil
    assert_nil Clock.parse("not-a-date")
  end
end

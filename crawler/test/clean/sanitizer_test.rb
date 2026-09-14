# frozen_string_literal: true

require "test_helper"

class SanitizerTest < Minitest::Test
  def test_clean_replaces_nbsp
    assert_equal "hello world", Sanitizer.clean("hello\u00A0world")
  end

  def test_clean_strips_bom_and_zero_width
    assert_equal "abc", Sanitizer.clean("\uFEFFabc\u200B")
  end

  def test_clean_replaces_html_nbsp
    assert_equal "a b", Sanitizer.clean("a&nbsp;b")
  end

  def test_clean_normalizes_newlines
    assert_equal "a\nb\nc", Sanitizer.clean("a\r\nb\rc")
  end

  def test_clean_returns_nil_for_nil
    assert_nil Sanitizer.clean(nil)
  end

  def test_clean_strips_whitespace
    assert_equal "text", Sanitizer.clean("  text  ")
  end
end

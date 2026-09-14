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

  def test_clean_removes_en_space
    assert_equal "香港居民", Sanitizer.clean("香港\u2002\u2002\u2002居民")
  end

  # --- normalize_url ---

  def test_normalize_url_upgrades_http
    assert_equal "https://example.com/a", Sanitizer.normalize_url("http://example.com/a")
  end

  def test_normalize_url_fixes_www_zcfgk_domain
    assert_equal "https://fgk.chinatax.gov.cn/zcfgk/c100016/c5212471/content.html",
                 Sanitizer.normalize_url("http://www.chinatax.gov.cn/zcfgk/c100016/c5212471/content.html")
  end

  def test_normalize_url_keeps_fgk_domain
    url = "https://fgk.chinatax.gov.cn/zcfgk/c100012/c5194956/content.html"
    assert_equal url, Sanitizer.normalize_url(url)
  end

  def test_normalize_url_keeps_www_for_other_paths
    assert_equal "https://www.chinatax.gov.cn/chinatax/c102035/gbtzsszn.html",
                 Sanitizer.normalize_url("http://www.chinatax.gov.cn/chinatax/c102035/gbtzsszn.html")
  end

  # --- clean_html ---

  def test_clean_html_removes_comments
    assert_equal "<p>abc</p>", Sanitizer.clean_html("<p>abc</p><!-- note -->")
  end

  def test_clean_html_removes_empty_anchor
    html = '<p><img src="x"><a href="http://old/c1/content.html"><!--x--></a></p>'
    assert_equal '<p><img src="x"></p>', Sanitizer.clean_html(html)
  end

  def test_clean_html_removes_punctuation_only_anchor
    html = '<p><img src="x"><a href="http://old/c1/content.html">）</a></p>'
    assert_equal '<p><img src="x"></p>', Sanitizer.clean_html(html)
  end

  def test_clean_html_fixes_polluted_mailto
    html = '<a href="http://100.12.64.119:80mailto:a@b.com">a@b.com</a>'
    assert_equal '<a href="mailto:a@b.com">a@b.com</a>', Sanitizer.clean_html(html)
  end

  def test_clean_html_keeps_normal_anchor
    html = '<a href="http://x/c1/content.html">《条例》</a>'
    assert_equal html, Sanitizer.clean_html(html)
  end
end

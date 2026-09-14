# frozen_string_literal: true

require "test_helper"
require "tmpdir"

class LoaderTest < Minitest::Test
  def test_settings_path_exists
    assert File.exist?(Loader.settings_path)
  end

  def test_current_loads_database_path
    assert_equal "../../database/content.sqlite", Loader.current.dig("database", "path")
  end

  def test_load_secrets_parses_key_value
    Dir.mktmpdir do |dir|
      path = File.join(dir, "secrets")
      File.write(path, "TAXMAN_TEST_FOO=bar\n# 注释行\nTAXMAN_TEST_BAZ=\"qux\"\n")
      Loader.load_secrets(path)
      assert_equal "bar", ENV["TAXMAN_TEST_FOO"]
      assert_equal "qux", ENV["TAXMAN_TEST_BAZ"]
    end
  ensure
    ENV.delete("TAXMAN_TEST_FOO")
    ENV.delete("TAXMAN_TEST_BAZ")
  end
end

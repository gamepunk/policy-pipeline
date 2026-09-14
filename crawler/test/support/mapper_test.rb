# frozen_string_literal: true

require "test_helper"

class MapperTest < Minitest::Test
  def test_code_for_circuit_open
    assert_equal "circuit_open", Mapper.code_for(Client::CircuitOpenError.new)
  end

  def test_code_for_timeout
    assert_equal "timeout", Mapper.code_for(Net::OpenTimeout.new)
    assert_equal "timeout", Mapper.code_for(Net::ReadTimeout.new)
  end

  def test_code_for_connection
    assert_equal "connection_failed", Mapper.code_for(Errno::ECONNREFUSED.new)
  end

  def test_code_for_http_error
    assert_equal "http_error", Mapper.code_for(Client::RequestError.new("boom"))
  end

  def test_code_for_unknown
    assert_equal "unknown_error", Mapper.code_for(RuntimeError.new("x"))
  end

  def test_compact_message
    err = Client::RequestError.new("boom")
    assert_equal "http_error: Client::RequestError boom", Mapper.compact_message(err)
  end
end

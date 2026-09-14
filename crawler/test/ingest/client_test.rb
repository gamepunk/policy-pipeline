# frozen_string_literal: true

require "test_helper"

class ClientTest < Minitest::Test
  include HttpTestHelpers

  def setup
    Client.reset_circuit!
  end

  def teardown
    Client.reset_circuit!
  end

  def test_get_parses_json
    client = Client.new(url: "https://example.com/x", transport: fake_transport('{"ok":true}'))
    assert_equal({ "ok" => true }, client.get(foo: 1))
  end

  def test_retry_succeeds_after_failures
    calls = 0
    ok_response = fake_response('{"ok":true}')
    transport = Object.new
    transport.define_singleton_method(:request) do |_req|
      calls += 1
      raise Net::ReadTimeout if calls < 3

      ok_response
    end
    sleeps = []
    client = Client.new(
      url: "https://example.com/x",
      transport: transport,
      sleep_proc: ->(sec) { sleeps << sec }
    )

    assert_equal({ "ok" => true }, client.get)
    assert_equal 3, calls
    assert_equal 2, sleeps.size
  end

  def test_non_success_raises_request_error
    client = Client.new(url: "https://example.com/x", transport: fake_transport("err", code: "500"))
    assert_raises(Client::RequestError) { client.get }
  end

  def test_circuit_opens_after_threshold
    config = { "sync" => { "circuit_failure_threshold" => 2, "circuit_cooldown_seconds" => 60 } }
    transport = Object.new
    transport.define_singleton_method(:request) { |_req| raise Errno::ECONNREFUSED }

    client = Client.new(
      url: "https://example.com/x",
      config: config,
      transport: transport,
      sleep_proc: ->(_sec) {}
    )

    2.times { assert_raises(Errno::ECONNREFUSED) { client.get } }
    assert_raises(Client::CircuitOpenError) { client.get }
  end

  def test_circuit_closes_after_cooldown
    config = { "sync" => { "circuit_failure_threshold" => 1, "circuit_cooldown_seconds" => -1 } }
    transport = Object.new
    transport.define_singleton_method(:request) { |_req| raise Errno::ECONNREFUSED }

    client = Client.new(
      url: "https://example.com/x",
      config: config,
      transport: transport,
      sleep_proc: ->(_sec) {}
    )

    assert_raises(Errno::ECONNREFUSED) { client.get }
    assert_raises(Errno::ECONNREFUSED) { client.get }
  end
end

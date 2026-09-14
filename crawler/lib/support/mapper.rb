# frozen_string_literal: true

require "net/http"
require "json"
require "socket"

module Mapper
  module_function

  def code_for(exception)
    case exception
    when Client::CircuitOpenError
      "circuit_open"
    when Net::OpenTimeout, Net::ReadTimeout
      "timeout"
    when Errno::ECONNREFUSED, Errno::ECONNRESET, SocketError, EOFError
      "connection_failed"
    when Client::RequestError
      "http_error"
    when ActiveRecord::RecordInvalid
      "record_invalid"
    when ActiveRecord::RecordNotFound
      "record_not_found"
    when JSON::ParserError
      "parse_error"
    else
      "unknown_error"
    end
  end

  def compact_message(exception)
    "#{code_for(exception)}: #{exception.class} #{exception.message}"
  end
end

# frozen_string_literal: true

require "net/http"
require "json"
require "uri"
require "digest"

# 轻量 HTTP client,标准库 Net::HTTP + JSON,不依赖 Faraday/Oj。
# 保留原版两个关键能力:指数退避重试、进程内熔断器。
class Client
  class CircuitOpenError < StandardError; end
  class RequestError < StandardError; end

  HEADERS = {
    "User-Agent" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)",
    "Accept" => "*/*",
    "Accept-Language" => "zh-CN,zh;q=0.9",
    "Origin" => "https://fgk.chinatax.gov.cn",
    "Referer" => "https://fgk.chinatax.gov.cn/"
  }.freeze

  RETRYABLE_ERRORS = [
    Net::OpenTimeout,
    Net::ReadTimeout,
    Errno::ECONNREFUSED,
    Errno::ECONNRESET,
    SocketError,
    EOFError
  ].freeze

  # 熔断器状态:进程内共享,key 是 url 的 hash。
  # CLI 每次运行都是全新进程,状态不需要跨进程/跨次运行持久化。
  @circuit_state = {}
  @circuit_mutex = Mutex.new

  class << self
    attr_reader :circuit_mutex

    def circuit_state
      @circuit_state
    end

    # 测试/异常恢复用:清空进程内熔断状态,避免跨用例污染
    def reset_circuit!
      @circuit_mutex.synchronize { @circuit_state.clear }
    end
  end

  # transport 可注入(默认走 Net::HTTP),测试传假对象即可不真发请求;
  # sleep_proc 可注入,测试重试逻辑时避免真实 sleep。
  def initialize(url:, headers: {}, config: Loader.current, transport: nil, sleep_proc: nil)
    @uri = URI.parse(url)
    @extra_headers = HEADERS.merge(headers.transform_keys(&:to_s))
    @config = config
    @transport = transport
    @sleep_proc = sleep_proc
    @circuit_key = Digest::SHA256.hexdigest(url.to_s)
  end

  def get(params = {})
    request_with_resilience do
      uri = @uri.dup
      uri.query = URI.encode_www_form(params)
      parse(perform_with_retry { http_get(uri) })
    end
  end

  def post(body:)
    request_with_resilience do
      parse(perform_with_retry { http_post(@uri, body) })
    end
  end

  private

  def http_get(uri)
    execute(Net::HTTP::Get.new(uri, @extra_headers), uri)
  end

  def http_post(uri, body)
    req = Net::HTTP::Post.new(uri, @extra_headers)
    req.body = body
    execute(req, uri)
  end

  def execute(req, uri)
    http = @transport || build_http(uri)

    res = http.request(req)
    raise RequestError, "HTTP #{res.code} for #{uri}" unless res.is_a?(Net::HTTPSuccess)

    res.body
  end

  def build_http(uri)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == "https"
    http.open_timeout = open_timeout
    http.read_timeout = request_timeout
    http
  end

  def perform_with_retry(max: 5, interval: 0.5, backoff_factor: 2, randomness: 0.2)
    attempt = 0
    begin
      attempt += 1
      yield
    rescue *RETRYABLE_ERRORS => e
      raise e if attempt >= max

      wait = interval * (backoff_factor**(attempt - 1))
      wait += wait * randomness * rand
      sleep_proc.call(wait)
      retry
    end
  end

  def request_with_resilience
    raise CircuitOpenError, "Circuit open for #{@uri}" if circuit_open?

    payload = yield
    payload.nil? ? register_failure!("Empty/invalid JSON payload") : clear_failure_state!
    payload
  rescue CircuitOpenError
    raise
  rescue => e
    register_failure!(e.message)
    raise
  end

  def request_timeout
    @config.dig("sync", "request_timeout_seconds") || 15
  end

  def open_timeout
    @config.dig("sync", "open_timeout_seconds") || 5
  end

  def sleep_proc
    @sleep_proc || ->(sec) { sleep(sec) }
  end

  def failure_threshold
    @config.dig("sync", "circuit_failure_threshold") || 5
  end

  def cooldown_seconds
    @config.dig("sync", "circuit_cooldown_seconds") || 60
  end

  def circuit_open?
    self.class.circuit_mutex.synchronize do
      state = self.class.circuit_state[@circuit_key]
      next false unless state&.dig(:open_until)

      Time.now.to_i < state[:open_until]
    end
  end

  def register_failure!(message)
    self.class.circuit_mutex.synchronize do
      state = (self.class.circuit_state[@circuit_key] ||= { count: 0, open_until: nil })
      state[:count] += 1

      if state[:count] >= failure_threshold
        state[:open_until] = Time.now.to_i + cooldown_seconds
        App.logger.warn(
          "[Client] Circuit opened url=#{@uri} count=#{state[:count]} " \
          "cooldown=#{cooldown_seconds}s reason=#{message}"
        )
      end
    end
  end

  def clear_failure_state!
    self.class.circuit_mutex.synchronize do
      self.class.circuit_state.delete(@circuit_key)
    end
  end

  def parse(body)
    JSON.parse(body)
  rescue JSON::ParserError
    nil
  end
end

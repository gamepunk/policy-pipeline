# frozen_string_literal: true

# 通用并发执行器:worker 线程只做无副作用计算(如 HTTP 请求),
# 结果收敛回主线程由 consumer 串行消费(写库),避免 SQLite 并发写。
# Search / Fetch 共用,消除两处重复的 Queue+Thread 样板代码。
module Runner
  module_function

  def run(items, concurrency, worker:, consumer:)
    return if items.empty?

    work_queue = Queue.new
    result_queue = Queue.new
    items.each { |item| work_queue << item }

    workers = Array.new(concurrency) do
      Thread.new do
        loop do
          begin
            item = work_queue.pop(true)
            result_queue << worker.call(item)
          rescue ThreadError
            break
          rescue Exception => e # rubocop:disable Lint/RescueException
            # worker 异常继续处理剩余项,异常对象交给主线程统一 raise
            result_queue << e
          end
        end
      end
    end

    processed = 0
    while processed < items.size
      result = result_queue.pop
      raise result if result.is_a?(Exception)

      consumer.call(result)
      processed += 1
    end
  ensure
    workers&.each { |w| w.kill if w.alive? }
  end
end

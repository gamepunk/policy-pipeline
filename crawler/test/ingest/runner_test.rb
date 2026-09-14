# frozen_string_literal: true

require "test_helper"

class RunnerTest < Minitest::Test
  def test_runs_all_items
    items = (1..20).to_a
    results = []
    Runner.run(
      items, 4,
      worker: ->(i) { i * 2 },
      consumer: ->(r) { results << r }
    )
    assert_equal items.map { |i| i * 2 }.sort, results.sort
  end

  def test_empty_items
    results = []
    Runner.run([], 4, worker: ->(i) { i }, consumer: ->(r) { results << r })
    assert_empty results
  end

  def test_worker_exception_propagates
    assert_raises(RuntimeError) do
      Runner.run([1, 2], 2, worker: ->(_i) { raise "boom" }, consumer: ->(_r) {})
    end
  end
end

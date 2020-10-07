defmodule Front.AggregatorTest do
  use ExUnit.Case

  alias Front.Aggregator

  test "aggregates tests" do
    {:ok, pid} = Aggregator.start_link()

    :ok = Aggregator.record_metrics(pid, %{status: :ok})
    :ok = Aggregator.record_metrics(pid, %{status: :ok})

    state = Aggregator.state(pid)

    assert 2 == state.transactions_count
    assert 0 == state.errors_count
  end

  test "aggregates errors" do
    {:ok, pid} = Aggregator.start_link()

    :ok = Aggregator.record_metrics(pid, %{status: :error, type: :foo})
    :ok = Aggregator.record_metrics(pid, %{status: :error, type: :bar})
    :ok = Aggregator.record_metrics(pid, %{status: :error, type: :foo})

    state = Aggregator.state(pid)

    assert 3 == state.transactions_count
    assert 3 == state.errors_count
    assert %{bar: 1, foo: 2} == state.errors
  end
end

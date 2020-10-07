defmodule Front.AggregatorTest do
  use Front.DataCase

  alias Front.Aggregator

  test "aggregates tests" do
    {:ok, pid} = Aggregator.start_link("aggregator_test1")

    :ok = Aggregator.record_metrics(pid, %{status: :ok})
    :ok = Aggregator.record_metrics(pid, %{status: :ok})

    {_test_run, state} = Aggregator.state(pid)

    assert 2 == state.transactions_count
    assert 0 == state.errors_count
  end

  test "aggregates errors" do
    {:ok, pid} = Aggregator.start_link("aggregator_test2")

    :ok = Aggregator.record_metrics(pid, %{status: :error, type: :foo})
    :ok = Aggregator.record_metrics(pid, %{status: :error, type: :bar})
    :ok = Aggregator.record_metrics(pid, %{status: :error, type: :foo})

    {_test_run, state} = Aggregator.state(pid)

    assert 3 == state.transactions_count
    assert 3 == state.errors_count
    assert %{bar: 1, foo: 2} == state.errors
  end

  test "periodically dumps data to the db" do
    {:ok, pid} = Aggregator.start_link("aggregator_test3")

    {test_run, _state} = Aggregator.state(pid)

    assert is_nil(test_run.data)

    :ok = Aggregator.record_metrics(pid, %{status: :error, type: :foo})
    :ok = Aggregator.record_metrics(pid, %{status: :error, type: :bar})
    :ok = Aggregator.record_metrics(pid, %{status: :error, type: :foo})

    Process.sleep(6_000)

    {test_run, _state} = Aggregator.state(pid)
    assert %{errors: %{bar: 1, foo: 2}, errors_count: 3, transactions_count: 3} == test_run.data
  end
end

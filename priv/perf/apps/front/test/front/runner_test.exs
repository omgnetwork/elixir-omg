defmodule Front.RunnerTest do
  use Front.DataCase

  alias Front.{Aggregator, Runner}

  defmodule TestCase do
    alias LoadTest.TestCase

    @behaviour TestCase

    @impl TestCase
    def run(_params) do
      %{status: :ok}
    end
  end

  describe "run/2" do
    test "runs and aggregates test resuts" do
      params = [runner_params: [rate: 1, id: :runner_test, state_period: 500], test_params: %{}]

      aggregator = Runner.run(TestCase, params)

      Process.sleep(4_000)

      {_test_run, state} = Aggregator.state(aggregator)

      assert %{errors: %{}, errors_count: 0, transactions_count: 3} == state
    end
  end
end

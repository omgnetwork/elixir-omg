defmodule LoadTest.MonitoringProcessTest do
  use ExUnit.Case

  alias ExPlasma.Encoding
  alias LoadTest.MonitoringProcess
  alias LoadTest.Scenario.Deposits

  test "aggregates tests" do
    token = Encoding.to_binary("0x0000000000000000000000000000000000000000")
    amount = 1_000_000_000_000_000_000

    config = %{
      chain_config: %{
        token: token,
        amount: amount
      },
      run_config: %{
        tps: 1,
        period_in_seconds: 5
      },
      timeout: :infinity
    }

    assert {:ok, _pid} = MonitoringProcess.start_link({Deposits, config})
  end
end

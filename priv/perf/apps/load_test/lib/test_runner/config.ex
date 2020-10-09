defmodule LoadTest.TestRunner.Config do
  alias ExPlasma.Encoding

  @tests %{
    "deposits" => LoadTest.Runner.Deposits
  }

  @configs %{
    "deposits" => %{
      token: Encoding.to_binary("0x0000000000000000000000000000000000000000"),
      initial_amount: 500_000_000_000_000_000,
      deposited_amount: 200_000_000_000_000_000,
      transferred_amount: 100_000_000_000_000_000
    }
  }
  def parse() do
    [test, rate, period] = System.argv()

    config = config(test, rate, period)

    runner_module = Map.fetch!(@tests, test)

    {runner_module, config}
  end

  defp config(test, rate, period) do
    rate_int = String.to_integer(rate)
    period_int = String.to_integer(period)

    run_config = %{
      tps: rate_int,
      period_in_seconds: period_int
    }

    chain_config = Map.fetch!(@configs, test)

    %{
      run_config: run_config,
      chain_config: chain_config,
      timeout: :infinity
    }
  end
end

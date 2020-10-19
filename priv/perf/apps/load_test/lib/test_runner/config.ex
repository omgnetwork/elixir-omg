# Copyright 2019-2020 OmiseGO Pte Ltd
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

defmodule LoadTest.TestRunner.Config do
  @moduledoc """
  Command line args parser for TestRunner.
  """
  alias ExPlasma.Encoding

  @tests %{
    "deposits" => LoadTest.Runner.Deposits
  }

  @configs %{
    "deposits" => %{
      token: Encoding.to_binary("0x0000000000000000000000000000000000000000"),
      initial_amount: 500_000_000_000_000_000,
      deposited_amount: 200_000_000_000_000_000,
      transferred_amount: 100_000_000_000_000_000,
      gas_price: 2_000_000_000
    }
  }
  def parse() do
    [test, rate, period, property] =
      case System.argv() do
        [test, rate, period] ->
          [test, rate, period, :mean]

        [test, rate, period, percentile] ->
          percentile = parse_percentile(percentile)
          [test, rate, period, percentile]
      end

    rate_int = String.to_integer(rate)
    period_int = String.to_integer(period)

    config = config(test, rate_int, period_int)

    runner_module = Map.fetch!(@tests, test)

    {runner_module, config, property}
  end

  defp config(test, rate_int, period_int) do
    # Chaperon's SpreadAsyns (https://github.com/polleverywhere/chaperon/blob/13cc4a2d2a7baacddf20c46397064b5e42a48d97/lib/chaperon/action/spread_async.ex)
    # spawns a separate process for each execution. VM may fail if too many processes are spawned
    if rate_int * period_int > 200_000, do: raise("too many processes")

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

  defp parse_percentile(percentile) do
    percentile_int = String.to_integer(percentile)

    # percentile should be divisible by 10 and < 100 (10, 20, ... 90)
    unless rem(percentile_int, 10) == 0 and div(percentile_int, 10) < 10 do
      raise("Wrong percentile")
    end

    {:percentile, percentile_int / 1}
  end
end

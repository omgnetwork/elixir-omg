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
end

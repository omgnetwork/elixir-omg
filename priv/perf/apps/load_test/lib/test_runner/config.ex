# Copyright 2019-2020 OMG Network Pte Ltd
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
  alias LoadTest.TestRunner.Help

  @tests %{
    "deposits" => LoadTest.Runner.Deposits,
    "transactions" => LoadTest.Runner.Transactions
  }

  @configs %{
    "deposits" => %{
      token: {:binary, "0x0000000000000000000000000000000000000000"},
      initial_amount: 500_000_000_000_000_000,
      deposited_amount: 200_000_000_000_000_000,
      transferred_amount: 100_000_000_000_000_000,
      gas_price: 2_000_000_000
    },
    "transactions" => %{
      token: "0x0000000000000000000000000000000000000000",
      initial_amount: 760,
      fee: 75
    }
  }

  def parse() do
    case System.argv() do
      ["make_assertions", start_time, end_time] ->
        start_time_integer = String.to_integer(start_time)
        end_time_integer = String.to_integer(end_time)

        {:make_assertions, start_time_integer, end_time_integer}

      [test, rate, period] ->
        {:run_tests, config(test, rate, period, "true")}

      [test, rate, period, make_assertions] ->
        {:run_tests, config(test, rate, period, make_assertions)}

      ["help"] ->
        Help.help()

      ["help", "env"] ->
        Help.help("env")

      ["help", name] ->
        Help.help(name)
    end
  end

  defp config(test, rate, period, make_assertions) do
    rate_int = String.to_integer(rate)
    period_int = String.to_integer(period)

    runner_module = Map.fetch!(@tests, test)

    # Chaperon's SpreadAsyns (https://github.com/polleverywhere/chaperon/blob/13cc4a2d2a7baacddf20c46397064b5e42a48d97/lib/chaperon/action/spread_async.ex)
    # spawns a separate process for each execution. VM may fail if too many processes are spawned
    if rate_int * period_int > 200_000, do: raise("too many processes")

    run_config = %{
      tps: rate_int,
      period_in_seconds: period_int
    }

    chain_config = read_config!(test)

    config = %{
      run_config: run_config,
      chain_config: chain_config,
      make_assertions: parse_boolean(make_assertions),
      timeout: :infinity
    }

    {runner_module, config}
  end

  defp parse_boolean(bool) do
    case bool do
      "true" -> true
      _ -> false
    end
  end

  defp read_config!(test) do
    config_path = System.get_env("TEST_CONFIG_PATH")

    case config_path do
      nil ->
        @configs
        |> Map.fetch!(test)
        |> parse_config_values()

      _ ->
        parse_config_file!(config_path, test)
    end
  end

  defp parse_config_file!(file_path, test) do
    default_config = Map.fetch!(@configs, test)
    config = file_path |> File.read!() |> Jason.decode!()

    default_config
    |> Enum.map(fn {key, default_value} ->
      string_key = Atom.to_string(key)

      value =
        case default_value do
          {type, value} -> {type, config[string_key] || value}
          value -> config[string_key] || value
        end

      {key, value}
    end)
    |> Map.new()
    |> parse_config_values()
  end

  defp parse_config_values(config) do
    config
    |> Enum.map(fn {key, value} ->
      parsed_value =
        case value do
          {:binary, string} -> Encoding.to_binary(string)
          value -> value
        end

      {key, parsed_value}
    end)
    |> Map.new()
  end
end

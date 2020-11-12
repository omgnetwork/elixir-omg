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

defmodule LoadTest.TestRunner do
  @moduledoc """
  This module runs tests using `mix run`. For example:

  mix run -e "LoadTest.TestRunner.run()" -- "deposits" "1" "5"

  It accepts three arguments:
  - test name
  - transactions per seconds
  - period in seconds

  You can also modify values for tests by providing `TEST_CONFIG_PATH` env variable, it should contain
  the path to json file. For example:

    TEST_CONFIG_PATH=./my_file mix run -e "LoadTest.TestRunner.run()" -- "deposits" "1" "5" 90

  It fetches all configuration params from env vars.
  """
  alias LoadTest.Service.Metrics
  alias LoadTest.TestRunner.Config

  def run() do
    case Config.parse() do
      {:ok, {runner_module, config}} -> run_test(runner_module, config)
      :ok -> :ok
    end
  end

  defp run_test(runner_module, config) do
    {:ok, _} = Metrics.start_link()

    start_datetime = DateTime.utc_now()

    Chaperon.run_load_test(runner_module, print_results: true, config: config)

    end_datetime = DateTime.utc_now()

    case Metrics.assert_metrics(start_datetime, end_datetime) |> IO.inspect() do
      :ok ->
        System.halt(0)

      {:error, errors} ->
        IO.inspect(errors, limit: :infinity)
        System.halt(1)
    end
  end
end

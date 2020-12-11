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

  @circleci_tag "env:perf_circleci"

  def run() do
    case Config.parse() do
      {:run_tests, {runner_module, config}} -> run_test(runner_module, config)
      {:make_assertions, start_time, end_time} -> make_assertions(start_time, end_time)
      :ok -> :ok
    end
  end

  defp run_test(runner_module, config) do
    case System.get_env("STATIX_TAG") do
      nil -> raise("STATIX_TAG is not set")
      _ -> :ok
    end

    start_datetime = DateTime.utc_now()

    maybe_add_custom_tag(start_datetime)

    Chaperon.run_load_test(runner_module, print_results: true, config: config)

    end_datetime = DateTime.utc_now()

    case config.make_assertions do
      true -> make_assertions(start_datetime, end_datetime)
      _ -> :ok
    end
  end

  defp make_assertions(start_time, end_time) do
    case Metrics.assert_metrics(start_time, end_time) do
      :ok ->
        System.halt(0)

      {:error, errors} ->
        # credo:disable-for-next-line
        IO.inspect("errors: #{inspect(errors)}")
        System.halt(1)
    end
  end

  defp maybe_add_custom_tag(start_date) do
    tags = Application.get_env(:statix, :tags)

    tags
    |> Enum.find(fn value -> value == @circleci_tag end)
    |> case do
      nil ->
        :ok

      _ ->
        postfix = start_date |> to_string |> String.replace(" ", "-") |> String.downcase()
        new_tag = @circleci_tag <> ":" <> postfix
        Application.put_env(:statix, :tags, [new_tag | tags])
    end
  end
end

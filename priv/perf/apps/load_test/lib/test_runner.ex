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

  Optional paramters:
  - Percentile. You can pass percentile as the fourth parameter. By default `mean` value is used.

  You can also modify values for tests by providing `TEST_CONFIG_PATH` env variable, it should contain
  the path to json file. For example:

    TEST_CONFIG_PATH=./my_file mix run -e "LoadTest.TestRunner.run()" -- "deposits" "1" "5" 90

  It fetches all configuration params from env vars.
  """
  alias LoadTest.TestRunner.Config

  def run() do
    {runner_module, config, property} = Config.parse()
    result = Chaperon.run_load_test(runner_module, print_results: true, config: config)

    # / 1 is to convert result to float (mean is float, percentiles are integers)[O
    case result.metrics["error_rate"][property] / 1 do
      0.0 ->
        System.halt(0)

      _ ->
        System.halt(1)
    end
  end
end

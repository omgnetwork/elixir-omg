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

  It fetches all configuration params from env vars.
  """
  alias LoadTest.TestRunner.Config

  def run() do
    {runner_module, config, property} = Config.parse()
    result = Chaperon.run_load_test(runner_module, print_results: true, config: config)

    case result.metrics["error_rate"][property] do
      0.0 ->
        System.halt(0)

      0 ->
        System.halt(0)

      _ ->
        System.halt(1)
    end
  end
end

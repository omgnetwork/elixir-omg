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

defmodule LoadTesting.Runner.WatcherInfo do
  @moduledoc """
  Load test for watcher info
  """
  use Chaperon.LoadTest

  def default_config(),
    do: %{
      merge_scenario_sessions: true
    }

  def scenarios(),
    do: [
      {{100, LoadTesting.Scenario.AccountTransactions},
       %{
         iterations: 10
       }}
    ]
end

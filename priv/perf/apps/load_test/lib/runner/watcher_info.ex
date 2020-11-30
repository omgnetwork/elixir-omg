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

defmodule LoadTest.Runner.WatcherInfoAccountApi do
  @moduledoc """
  Tests all the `account.*` apis on the watcher-info

  Run with `mix test apps/load_test/test/load_tests/runner/watcher_info_test.exs`

  This test first creates a new address and funds from the faucet.
  Next it calls the watcher-info apis:
    - `account.get_balance`
    - `account.get_utxos`
    - `account.get_transactions`
  It then creates a transaction from the address, measuring the time taken.
  """
  use Chaperon.LoadTest

  @default_config %{
    concurrent_sessions: 1,
    iterations: 1,
    merge_scenario_sessions: true
  }

  def default_config() do
    Application.get_env(:load_test, :watcher_info_test_config, @default_config)
  end

  def scenarios() do
    %{concurrent_sessions: concurrent_sessions} = default_config()

    [
      {{concurrent_sessions, LoadTest.Scenario.AccountTransactions}, %{}}
    ]
  end
end

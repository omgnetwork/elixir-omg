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

defmodule LoadTest.Runner.UtxosLoad do
  @moduledoc """
  Creates utxos and submits transactions to test how child chain performs when
  there are many utxos in its state.

  Run with `mix test apps/load_test/test/load_tests/runner/utxos_load_test.exs`

  This test first creates a number of utxos by funding a new address from the faucet and then
  successively splitting its utxos into 4 until the desired number of utxos is reached.

  It then creates a number of transactions from the address, measuring the time taken.
  """
  use Chaperon.LoadTest

  alias LoadTest.Ethereum.Account

  @default_config %{
    concurrent_sessions: 1,
    utxos_to_create_per_session: 30,
    transactions_per_session: 10
  }

  def default_config() do
    utxo_load_test_config = Application.get_env(:load_test, :utxo_load_test_config, @default_config)

    %{
      concurrent_sessions: utxo_load_test_config[:concurrent_sessions],
      utxos_to_create_per_session: utxo_load_test_config[:utxos_to_create_per_session],
      transactions_per_session: utxo_load_test_config[:transactions_per_session]
    }
  end

  def scenarios() do
    {:ok, sender} = Account.new()

    %{concurrent_sessions: concurrent_sessions} = default_config()

    [
      {{concurrent_sessions, [LoadTest.Scenario.CreateUtxos, LoadTest.Scenario.SpendEthUtxo]},
       %{
         sender: sender,
         receiver: sender
       }}
    ]
  end
end

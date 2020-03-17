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

defmodule LoadTest.ChildChain.UtxosLoadTest do
  @moduledoc """
  Creates utxos and submits transactions to test
  how child chain performs when there are many utxos in it's state.
  """
  use Chaperon.LoadTest

  alias LoadTest.Account

  @concurrent_session 4
  @default_config %{
    utxos_to_create_per_session: 3_000_000,
    transactions_per_session: 100_000
  }

  def default_config() do
    utxo_load_test_config = Application.get_env(:load_test, :utxo_load_test_config, @default_config)

    %{
      utxos_to_create_per_session: utxo_load_test_config[:utxos_to_create_per_session],
      transactions_per_session: utxo_load_test_config[:transactions_per_session]
    }
  end

  def scenarios() do
    {:ok, sender} = Account.new()

    [
      {{@concurrent_session, [LoadTest.Scenario.CreateUtxos, LoadTest.Scenario.SpendUtxos]},
       %{
         sender: sender
       }}
    ]
  end
end

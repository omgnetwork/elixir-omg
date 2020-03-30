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

defmodule WatcherInfoApiTest do
  use Cabbage.Feature, async: true, file: "watcher_info_api.feature"

  require Logger

  alias Itest.Account

  alias Itest.Client
  alias Itest.Transactions.Currency

  setup do
    alice = Account.take_accounts(1)
    %{alice_account: alice}
  end

  defwhen ~r/^Alice deposit "(?<amount>[^"]+)" ETH to the root chain creating 1 utxo$/,
          %{amount: amount},
          %{alice_account: alice_account} = state do
    {alice_addr, alice_priv} = alice_account

    {:ok, receipt_hash} =
      amount
      |> Currency.to_wei()
      |> Client.deposit(alice_addr, Itest.PlasmaFramework.vault(Currency.ether()))

    state
  end

  defthen ~r/^Alice should able to call watcher info api \/account.get_utxos and it return the utxo and the paginating content correctly$/,
          %{amount: amount},
          %{alice_account: alice_account} do
    {alice_addr, alice_priv} = alice_account

  end

  defp assert_equal(left, right, message) do
    assert(left == right, "Expected #{left}, but have #{right}." <> message)
  end
end

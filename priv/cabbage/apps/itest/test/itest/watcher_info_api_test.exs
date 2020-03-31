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
  alias Itest.ApiModel.WatcherSecurityCriticalConfiguration
  alias Itest.Client
  alias Itest.Transactions.Currency

  setup do
    accounts = Account.take_accounts(1)
    alice_account = Enum.at(accounts, 0)
    %{alice_account: alice_account}
  end

  defwhen ~r/^Alice deposit "(?<amount>[^"]+)" ETH to the root chain creating 1 utxo$/,
          %{amount: amount},
          %{alice_account: alice_account} = state do
    {alice_addr, _alice_priv} = alice_account

    {:ok, receipt_hash} =
      amount
      |> Currency.to_wei()
      |> Client.deposit(alice_addr, Itest.PlasmaFramework.vault(Currency.ether()))

    {:ok, state}
  end

  defthen ~r/^Alice should able to call watcher_info \/account.get_utxos and it return the utxo and the paginating content correctly$/,
          _,
          %{alice_account: alice_account} = state do

    {alice_addr, alice_priv} = alice_account

    {:ok, response} =
      WatcherSecurityCriticalAPI.Api.Configuration.configuration_get(WatcherSecurityCriticalAPI.Connection.new())

    watcher_security_critical_config =
      WatcherSecurityCriticalConfiguration.to_struct(Jason.decode!(response.body)["data"])

    finality_margin_blocks = watcher_security_critical_config.deposit_finality_margin

    to_milliseconds = 1000
    geth_block_every = 1

    finality_margin_blocks
    |> Kernel.*(geth_block_every)
    |> Kernel.*(to_milliseconds)
    |> Kernel.round()
    |> Process.sleep()

    utxos = Client.get_utxos(alice_addr)

    assert_equal(length(utxos), 1, "utxo length")
  end

  defp assert_equal(left, right, message) do
    assert(left == right, "Expected #{left}, but have #{right}." <> message)
  end
end

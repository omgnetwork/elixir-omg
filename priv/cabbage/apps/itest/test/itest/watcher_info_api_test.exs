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

  @geth_block_every 1
  @to_milliseconds 1000

  setup do
    accounts = Account.take_accounts(1)
    alice_account = Enum.at(accounts, 0)
    %{alice_account: alice_account}
  end

  defgiven ~r/^Alice deposits "(?<amount>[^"]+)" ETH to the root chain creating 1 utxo$/,
           %{amount: amount},
           %{alice_account: alice_account} = state do
    {alice_addr, _alice_priv} = alice_account

    {:ok, _} = Client.deposit(Currency.to_wei(amount), alice_addr, Itest.PlasmaFramework.vault(Currency.ether()))
    {:ok, state}
  end

  defthen ~r/^Alice is able to paginate her UTXOs$/,
          _,
          %{alice_account: alice_account} do
    {alice_addr, _alice_priv} = alice_account

    {:ok, response} =
      WatcherSecurityCriticalAPI.Api.Configuration.configuration_get(WatcherSecurityCriticalAPI.Connection.new())

    watcher_security_critical_config =
      WatcherSecurityCriticalConfiguration.to_struct(Jason.decode!(response.body)["data"])

    finality_margin_blocks = watcher_security_critical_config.deposit_finality_margin

    wait_finality_margin_blocks(finality_margin_blocks)
    Itest.Poller.pull_balance_until_amount(alice_addr, Currency.to_wei(1))

    {:ok, data} = Client.get_utxos(%{address: alice_addr, page: 1, limit: 10})

    %{"data" => utxos, "data_paging" => data_paging} = data
    assert_equal(1, length(utxos), "for depositing 1 tx")
    assert_equal(Currency.to_wei(1), Enum.at(utxos, 0)["amount"], "for first utxo")
    assert_equal(true, Map.equal?(data_paging, %{"page" => 1, "limit" => 10}), "as data_paging")

    # deposit again for another utxo
    {:ok, _} = Client.deposit(Currency.to_wei(2), alice_addr, Itest.PlasmaFramework.vault(Currency.ether()))

    wait_finality_margin_blocks(finality_margin_blocks)
    Itest.Poller.pull_balance_until_amount(alice_addr, Currency.to_wei(1 + 2))

    {:ok, data} = Client.get_utxos(%{address: alice_addr, page: 1, limit: 2})

    %{"data" => utxos, "data_paging" => data_paging} = data
    assert_equal(2, length(utxos), "for depositing 2 tx")
    assert_equal(Currency.to_wei(1), Enum.at(utxos, 0)["amount"], "for first utxo")
    assert_equal(Currency.to_wei(2), Enum.at(utxos, 1)["amount"], "for second utxo")
    assert_equal(true, Map.equal?(data_paging, %{"page" => 1, "limit" => 2}), "as data_paging")
  end

  defp assert_equal(left, right, message) do
    assert(left == right, "Expected #{left}, but have #{right}." <> message)
  end

  defp wait_finality_margin_blocks(finality_margin_blocks) do
    # sometimes waiting just 1 margin blocks is not enough
    finality_margin_blocks
    |> Kernel.*(@geth_block_every)
    |> Kernel.*(@to_milliseconds)
    |> Kernel.round()
    |> Process.sleep()
  end
end

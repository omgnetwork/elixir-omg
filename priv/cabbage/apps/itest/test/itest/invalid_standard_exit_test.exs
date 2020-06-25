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
defmodule InvalidStandardExitsTests do
  use Cabbage.Feature, async: false, file: "invalid_standard_exits.feature"
  @moduletag :invalid_standard_exits_tests

  require Logger

  alias Itest.Account
  alias Itest.ApiModel.Utxo
  alias Itest.Client
  alias Itest.StandardExitChallengeClient
  alias Itest.StandardExitClient
  alias Itest.Transactions.Currency
  alias WatcherSecurityCriticalAPI.Api.Status

  import Itest.Poller, only: [pull_api_until_successful: 3, pull_api_until_successful: 4, all_events_in_status?: 1]

  setup do
    [{alice_account, alice_pkey}, {bob_account, _bob_pkey}, {carol_account, carol_pkey}] = Account.take_accounts(3)

    %{
      alice_account: alice_account,
      alice_pkey: alice_pkey,
      bob_account: bob_account,
      carol_account: carol_account,
      carol_pkey: carol_pkey,
      alice_gas: 0
    }
  end

  defgiven ~r/^Alice deposited "(?<amount>[^"]+)" ETH on the child chain$/,
           %{amount: amount},
           %{alice_account: alice_account} = state do
    initial_balance_on_root_chain = Itest.Poller.root_chain_get_balance(alice_account)

    expecting_amount = Currency.to_wei(amount)

    {:ok, receipt_hash} = Client.deposit(expecting_amount, alice_account, Itest.PlasmaFramework.vault(Currency.ether()))
    gas_used = Client.get_gas_used(receipt_hash)

    %{"amount" => ^expecting_amount} = Client.get_exact_balance(alice_account, expecting_amount)

    new_state =
      state
      |> Map.update!(:alice_gas, fn current_gas -> current_gas + gas_used end)
      |> Map.put_new(:alice_initial_balance_on_root_chain, initial_balance_on_root_chain)

    {:ok, new_state}
  end

  defgiven ~r/^Alice received "(?<amount>[^"]+)" ETH on the child chain$/,
           %{amount: amount},
           %{alice_account: alice_account, carol_account: carol_account, carol_pkey: carol_pkey} = state do
    initial_balance_on_root_chain = Itest.Poller.root_chain_get_balance(alice_account)

    carol_amount =
      amount
      |> Currency.to_wei()
      # a little extra to cover fees etc and let Alice get amount
      |> Kernel.+(1_000_000_000_000_000_000)

    {:ok, _receipt_hash} = Client.deposit(carol_amount, carol_account, Itest.PlasmaFramework.vault(Currency.ether()))

    %{"amount" => ^carol_amount} = Client.get_exact_balance(carol_account, carol_amount)

    {:ok, [sign_hash, typed_data, _txbytes]} =
      Client.create_transaction(
        Currency.to_wei(amount),
        carol_account,
        alice_account
      )

    # pattern match just to check success, since this is what `Client` returns to us
    # TODO: improve with an `{:ok, ...}` perhaps?
    %Itest.ApiModel.SubmitTransactionResponse{blknum: _} =
      Client.submit_transaction(typed_data, sign_hash, [carol_pkey])

    expecting_amount = Currency.to_wei(amount)
    %{"amount" => ^expecting_amount} = Client.get_exact_balance(alice_account, expecting_amount)

    new_state = Map.put_new(state, :alice_initial_balance_on_root_chain, initial_balance_on_root_chain)

    {:ok, new_state}
  end

  defthen ~r/^The child chain is secure$/,
          _,
          %{} = state do
    assert all_events_in_status?([])
    {:ok, Map.put(state, :prior_byzantine_events, [])}
  end

  defwhen ~r/^Alice sends Bob "(?<amount>[^"]+)" ETH on the child chain$/,
          %{amount: amount},
          %{alice_account: alice_account, alice_pkey: alice_pkey, bob_account: bob_account} = state do
    {:ok, [sign_hash, typed_data, _txbytes]} =
      Client.create_transaction(
        Currency.to_wei(amount),
        alice_account,
        bob_account
      )

    # get a public-API response that contains exactly the UTXO that alice just spent, for later exiting
    %{"message" => %{"input0" => %{"blknum" => blknum, "oindex" => oindex, "txindex" => txindex}}} = typed_data
    alice_recently_spent_utxo_pos = ExPlasma.Utxo.pos(%{blknum: blknum, oindex: oindex, txindex: txindex})
    alice_recently_spent_utxo_pos = get_particular_utxo(alice_account, alice_recently_spent_utxo_pos)

    %Itest.ApiModel.SubmitTransactionResponse{blknum: _} =
      Client.submit_transaction(typed_data, sign_hash, [alice_pkey])

    {:ok, Map.put_new(state, :alice_recently_spent_utxo_pos, alice_recently_spent_utxo_pos)}
  end

  defwhen ~r/^Alice starts a standard exit on the child chain from her recently spent input$/,
          _,
          %{alice_account: alice_account, alice_recently_spent_utxo_pos: alice_recently_spent_utxo_pos} = state do
    standard_exit_client = %StandardExitClient{address: alice_account, utxo: alice_recently_spent_utxo_pos}
    se = StandardExitClient.start_standard_exit(standard_exit_client)

    gas_used1 = Client.get_gas_used(se.start_standard_exit_hash)
    gas_used2 = Client.get_gas_used(se.add_exit_queue_hash)

    new_state =
      state
      |> Map.put(:standard_exit, se)
      |> Map.update!(:alice_gas, fn current_gas -> current_gas + gas_used1 + gas_used2 end)
      |> Map.put_new(:alice_bond, se.standard_exit_bond_size)

    {:ok, new_state}
  end

  defwhen ~r/^Bob detects a new "(?<event>[^"]+)"$/,
          %{event: event},
          %{prior_byzantine_events: prior_byzantine_events} = state do
    assert all_events_in_status?([event | prior_byzantine_events])
    {:ok, Map.put(state, :prior_byzantine_events, [event | prior_byzantine_events])}
  end

  defwhen ~r/^Bob challenges an invalid exit$/, _, %{bob_account: bob_account} = state do
    pull_api_until_successful(Status, :status_get, WatcherSecurityCriticalAPI.Connection.new())
    |> Map.fetch!("byzantine_events")
    |> hd
    |> get_in(["details", "utxo_pos"])
    |> StandardExitChallengeClient.challenge_standard_exit(bob_account)

    {:ok, state}
  end

  defthen ~r/^Exits are processed$/, _, state do
    # need n_exits: <many>, because we're trying to prove that Alice's processing of the challenged exit fails
    # otherwise, you're risking not processing "enough" exits and it will seem like Alice's exit got challenged, while
    # it is not necessarily true
    se = StandardExitClient.wait_and_process_standard_exit(state.standard_exit, n_exits: 2000)
    gas_used = Client.get_gas_used(se.process_exit_receipt_hash)

    new_state =
      state
      |> Map.update!(:alice_gas, fn current_gas -> current_gas + gas_used end)
      |> Map.put(:standard_exit, se)

    {:ok, new_state}
  end

  defthen ~r/^Alice should have "(?<difference>[^"]+)" ETH less on the root chain$/,
          %{difference: difference},
          %{
            alice_initial_balance_on_root_chain: alice_initial_balance_on_root_chain,
            alice_account: alice_account,
            alice_gas: alice_gas,
            alice_bond: alice_bond
          } = state do
    alice_ethereum_balance = Itest.Poller.root_chain_get_balance(alice_account)

    assert alice_ethereum_balance ==
             alice_initial_balance_on_root_chain - Currency.to_wei(difference) - alice_gas - alice_bond

    {:ok, state}
  end

  defp get_particular_utxo(address, utxo_pos) do
    payload = %WatcherInfoAPI.Model.AddressBodySchema1{address: address}

    response =
      pull_api_until_successful(
        WatcherInfoAPI.Api.Account,
        :account_get_utxos,
        WatcherInfoAPI.Connection.new(),
        payload
      )

    response |> Enum.find(&(&1["utxo_pos"] == utxo_pos)) |> Utxo.to_struct()
  end
end

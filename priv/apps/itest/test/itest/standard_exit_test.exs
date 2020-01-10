defmodule StandardExitsTests do
  use Cabbage.Feature, async: false, file: "standard_exits.feature"

  require Logger

  alias Itest.Account
  alias Itest.Client
  alias Itest.StandardExitClient
  alias Itest.Transactions.Currency

  setup do
    [{alice_account, alice_pkey}, {bob_account, _bob_pkey}] = Account.take_accounts(2)

    %{alice_account: alice_account, alice_pkey: alice_pkey, bob_account: bob_account, gas: 0}
  end

<<<<<<< HEAD
  defwhen ~r/^Alice deposits "(?<amount>[^"]+)" ETH to the root chain$/,
          %{amount: amount},
          %{alice_account: alice_account} = state do
    initial_balance = Itest.Poller.eth_get_balance(alice_account)
=======
  defwhen ~r/^Alice deposits "(?<amount>[^"]+)" ETH to the network$/,
          %{amount: amount},
          %{alice_account: alice_account} = state do
    {:ok, initial_balance} = Client.eth_get_balance(alice_account)
    {initial_balance, ""} = initial_balance |> String.replace_prefix("0x", "") |> Integer.parse(16)
>>>>>>> feature: introduce cabbage

    {:ok, receipt_hash} =
      amount
      |> Currency.to_wei()
      |> Client.deposit(alice_account, Itest.Account.vault(Currency.ether()))

    gas_used = Client.get_gas_used(receipt_hash)

    {_, new_state} =
      Map.get_and_update!(state, :gas, fn current_gas ->
        {current_gas, current_gas + gas_used}
      end)

<<<<<<< HEAD
    balance_after_deposit = Itest.Poller.eth_get_balance(alice_account)
=======
    {:ok, balance_after_deposit} = Client.eth_get_balance(alice_account)
    {balance_after_deposit, ""} = balance_after_deposit |> String.replace_prefix("0x", "") |> Integer.parse(16)
>>>>>>> feature: introduce cabbage

    state = Map.put_new(new_state, :alice_ethereum_balance, balance_after_deposit)
    {:ok, Map.put_new(state, :alice_initial_balance, initial_balance)}
  end

<<<<<<< HEAD
  defthen ~r/^Alice should have "(?<amount>[^"]+)" ETH on the child chain$/,
=======
  defthen ~r/^Alice should have "(?<amount>[^"]+)" ETH on the network$/,
>>>>>>> feature: introduce cabbage
          %{amount: amount},
          %{alice_account: alice_account} = state do
    expecting_amount = Currency.to_wei(amount)

    balance = Client.get_balance(alice_account, expecting_amount)

    balance = balance["amount"]
    assert_equal(expecting_amount, balance, "For #{alice_account}")
    {:ok, state}
  end

<<<<<<< HEAD
  defwhen ~r/^Alice starts a standard exit on the child chain$/, _, %{alice_account: alice_account} = state do
=======
  defwhen ~r/^Alice starts a standard exit on the network$/, _, %{alice_account: alice_account} = state do
>>>>>>> feature: introduce cabbage
    se = StandardExitClient.start_standard_exit(alice_account)
    state = Map.put_new(state, :standard_exit_total_gas_used, se.total_gas_used)

    {:ok, state}
  end

<<<<<<< HEAD
  defthen ~r/^Alice should have "(?<amount>[^"]+)" ETH on the child chain after finality margin$/,
          %{amount: amount},
          %{alice_account: alice_account} = state do
    _ = Logger.info("Alice should have #{amount} ETH on the child chain after finality margin")
=======
  defthen ~r/^Alice should have "(?<amount>[^"]+)" ETH on the network after finality margin$/,
          %{amount: amount},
          %{alice_account: alice_account} = state do
    _ = Logger.info("Alice should have #{amount} ETH on the network after finality margin")
>>>>>>> feature: introduce cabbage

    case amount do
      "0" ->
        assert Client.get_balance(alice_account, Currency.to_wei(amount)) == []

      _ ->
        %{"amount" => network_amount} = Client.get_balance(alice_account, Currency.to_wei(amount))
        assert network_amount == Currency.to_wei(amount)
    end

<<<<<<< HEAD
    balance = Itest.Poller.eth_get_balance(alice_account)
    {:ok, Map.put(state, :alice_ethereum_balance, balance)}
  end

  defthen ~r/^Alice should have "(?<amount>[^"]+)" ETH on the blockchain$/,
=======
    {:ok, balance} = Client.eth_get_balance(alice_account)
    {balance, ""} = balance |> String.replace_prefix("0x", "") |> Integer.parse(16)
    {:ok, Map.put(state, :alice_ethereum_balance, balance)}
  end

  defthen ~r/^Alice should have "(?<amount>[^"]+)" ETH on the blockchain/,
>>>>>>> feature: introduce cabbage
          %{amount: amount},
          %{
            alice_account: _alice_account,
            alice_initial_balance: alice_initial_balance,
            alice_ethereum_balance: alice_ethereum_balance
          } = state do
    gas_wei = state[:standard_exit_total_gas_used] + state[:gas]
    assert_equal(alice_ethereum_balance, alice_initial_balance - gas_wei)
    assert_equal(alice_ethereum_balance, Currency.to_wei(amount) - gas_wei)
    {:ok, state}
  end

  defp assert_equal(left, right) do
    assert_equal(left, right, "")
  end

  defp assert_equal(left, right, message) do
    assert(left == right, "Expected #{left}, but have #{right}." <> message)
  end
end

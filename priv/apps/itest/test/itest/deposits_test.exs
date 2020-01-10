defmodule DepositsTests do
  use Cabbage.Feature, async: true, file: "deposits.feature"

  require Logger

  alias Itest.Account
  alias Itest.Client
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
  defwhen ~r/^Alice sends Bob "(?<amount>[^"]+)" ETH on the child chain$/,
=======
  defwhen ~r/^Alice sends Bob "(?<amount>[^"]+)" ETH on the network$/,
>>>>>>> feature: introduce cabbage
          %{amount: amount},
          %{alice_account: alice_account, alice_pkey: alice_pkey, bob_account: bob_account} = state do
    {:ok, [sign_hash, typed_data, _txbytes]} =
      Client.create_transaction(
        Currency.to_wei(amount),
        alice_account,
        bob_account
      )

    _ = Client.submit_transaction(typed_data, sign_hash, alice_pkey)

    {:ok, state}
  end

<<<<<<< HEAD
  defthen ~r/^Bob should have "(?<amount>[^"]+)" ETH on the child chain$/,
=======
  defthen ~r/^Bob should have "(?<amount>[^"]+)" ETH on the network$/,
>>>>>>> feature: introduce cabbage
          %{amount: amount},
          %{bob_account: bob_account} = state do
    balance = Client.get_balance(bob_account)["amount"]
    assert_equal(Currency.to_wei(amount), balance, "For #{bob_account}.")

    {:ok, state}
  end

  defp assert_equal(left, right, message) do
    assert(left == right, "Expected #{left}, but have #{right}." <> message)
  end
end

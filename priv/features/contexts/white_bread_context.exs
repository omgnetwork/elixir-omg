defmodule WhiteBreadContext do
  @moduledoc """
    provides execution environment for White Bread gerkin style tests
  """
  use WhiteBread.Context
  require Logger
  alias Itest.Transactions.Currency
  alias Itest.Account
  alias Itest.Client
  alias Itest.StandardExitClient

  # TODO Fix this, expose via API, also its 12 blocks
  @finality_margin 12

  @default_timeout 60_000
  scenario_timeouts(fn _feature, scenario ->
    case scenario.name do
      "Alice starts a Standard Exit" -> @default_timeout * 3
      _ -> @default_timeout * 2
    end
  end)

  scenario_starting_state(fn _ ->
    [{alice_account, alice_pkey}, {bob_account, _bob_pkey}] = Account.take_accounts(2)
    %{alice_account: alice_account, alice_pkey: alice_pkey, bob_account: bob_account, gas: 0}
  end)

  when_(
    ~r/^Alice deposits "(?<amount>[^"]+)" ETH to the network$/,
    fn %{alice_account: alice_account} = state, %{amount: amount} ->
      {:ok, initial_balance} = Client.eth_get_balance(alice_account)
      {initial_balance, ""} = initial_balance |> String.replace_prefix("0x", "") |> Integer.parse(16)

      {:ok, receipt_hash} =
        amount
        |> Currency.to_wei()
        |> Client.deposit(alice_account, Account.vault())

      gas_used = Client.get_gas_used(receipt_hash)

      {_, new_state} =
        Map.get_and_update!(state, :gas, fn current_gas ->
          {current_gas, current_gas + gas_used}
        end)

      {:ok, balance_after_deposit} = Client.eth_get_balance(alice_account)
      {balance_after_deposit, ""} = balance_after_deposit |> String.replace_prefix("0x", "") |> Integer.parse(16)

      state = Map.put_new(new_state, :alice_ethereum_balance, balance_after_deposit)
      {:ok, Map.put_new(state, :alice_initial_balance, initial_balance)}
    end
  )

  when_(
    ~r/^Alice sends Bob "(?<amount>[^"]+)" ETH on the network$/,
    fn %{alice_account: alice_account, alice_pkey: alice_pkey, bob_account: bob_account} = state, %{amount: amount} ->
      {:ok, [sign_hash, typed_data]} =
        Client.create_transaction(
          Currency.to_wei(amount),
          alice_account,
          bob_account
        )

      _ = Client.submit_transaction(typed_data, sign_hash, alice_pkey)

      {:ok, state}
    end
  )

  when_(
    ~r/^Alice starts a standard exit on the network$/,
    fn %{alice_account: alice_account} = state ->
      se = StandardExitClient.start_standard_exit(alice_account)
      state = Map.put_new(state, :standard_exit_total_gas_used, se.total_gas_used)

      {:ok, state}
    end
  )

  then_(
    ~r/^Alice should have "(?<amount>[^"]+)" ETH on the network after finality margin$/,
    fn %{alice_account: alice_account} = state, %{amount: amount} ->
      Process.sleep(@finality_margin * 500 + 15_000)

      assert [] = Client.get_balance(alice_account, Currency.to_wei(amount))

      {:ok, balance} = Client.eth_get_balance(alice_account)
      {balance, ""} = balance |> String.replace_prefix("0x", "") |> Integer.parse(16)
      {:ok, Map.put(state, :alice_ethereum_balance, balance)}
    end
  )

  then_(
    ~r/^Alice should have "(?<amount>[^"]+)" ETH on the network$/,
    fn %{alice_account: alice_account} = state, %{amount: amount} ->
      expecting_amount = Currency.to_wei(amount)

      balance = Client.get_balance(alice_account, expecting_amount)

      balance = balance["amount"]
      assert_equal(expecting_amount, balance, "For #{alice_account}")
      {:ok, state}
    end
  )

  then_(
    ~r/^Bob should have "(?<amount>[^"]+)" ETH on the network$/,
    fn %{bob_account: bob_account} = state, %{amount: amount} ->
      balance = Client.get_balance(bob_account)["amount"]
      assert_equal(Currency.to_wei(amount), balance, "For #{bob_account}.")

      {:ok, state}
    end
  )

  then_(
    ~r/^Alice should have "(?<amount>[^"]+)" ETH on the blockchain/,
    fn %{
         alice_account: _alice_account,
         alice_initial_balance: alice_initial_balance,
         alice_ethereum_balance: alice_ethereum_balance
       } = state,
       %{amount: amount} ->
      gas_wei = state[:standard_exit_total_gas_used] + state[:gas]
      assert_equal(alice_ethereum_balance, alice_initial_balance - gas_wei)
      assert_equal(alice_ethereum_balance, Currency.to_wei(amount) - gas_wei)
      {:ok, state}
    end
  )

  def assert_equal(left, right) do
    assert_equal(left, right, "")
  end

  def assert_equal(left, right, message) do
    assert(left == right, "Expected #{left}, but have #{right}." <> message)
  end
end

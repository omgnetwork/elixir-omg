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
  alias Itest.InFlightExitClient

  # TODO Fix this, expose via API, also its 12 blocks
  @finality_margin 12

  @default_timeout 60_000
  scenario_timeouts(fn _feature, scenario ->
    case scenario.name do
      "Alice sends Bob funds" -> @default_timeout * 2
      "Alice starts a Standard Exit" -> @default_timeout * 30
      "Alice starts an In Flight Exit" -> @default_timeout * 30
      _ -> @default_timeout
    end
  end)

  scenario_starting_state(fn o ->
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
      {:ok, [sign_hash, typed_data, _txbytes]} =
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

  when_(
    ~r/^Alice starts an in flight exit on the network$/,
    fn %{alice_account: alice_account, alice_pkey: alice_key, bob_account: bob_account} = state ->
      se = InFlightExitClient.start_in_flight_exit(alice_account, alice_key, bob_account)
      {:ok, state}
    end
  )

  then_(
    ~r/^Alice should have "0" ETH on the network after finality margin$/,
    fn %{alice_account: alice_account} = state, %{} ->
      Process.sleep(@finality_margin * 1000 + 15_000)
      IO.inspect("alice address #{alice_account}")
      assert [] = Client.get_balance(alice_account, 1)
      {:ok, balance} = Ethereumex.HttpClient.eth_get_balance(alice_account)
      {balance, ""} = balance |> String.replace_prefix("0x", "") |> Integer.parse(16)
      IO.inspect("alice balance #{balance}")
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
      assert_equal(alice_ethereum_balance, alice_initial_balance - gas_wei, " compared to initial balance")
      assert_equal(alice_ethereum_balance, Currency.to_wei(amount) - gas_wei, " compared to amount")
      {:ok, state}
    end
  )

  when_(
    ~r/^Operator deploys "(?<service>[^"]+)"$/,
    fn state, %{service: service} ->
      {:ok, response} =
        case service do
          "Child Chain" ->
            Client.get_child_chain_alarms()

          "Watcher" ->
            Client.get_watcher_alarms()

          "Watcher Info" ->
            Client.get_watcher_info_alarms()
        end

      body = Jason.decode!(response.body)
      {:ok, Map.put(state, :service_response, body)}
    end
  )

  then_(
    ~r/^Operator can read it's service name as "(?<service_name>[^"]+)"/,
    fn state, %{service_name: service_name} ->
      case service_name do
        "watcher_info" ->
          # TODO remove when implemented
          assert state.service_response["service_name"] == "watcher"

        _ ->
          assert state.service_response["service_name"] == service_name
      end

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

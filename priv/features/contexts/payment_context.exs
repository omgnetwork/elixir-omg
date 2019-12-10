defmodule PaymentContext do
  @moduledoc """
  Provides step definitions for the expected, happy cases
  """

  use WhiteBread.Context
  require Logger

  alias Itest.Transactions.Currency
  alias Itest.Account
  alias Itest.Client
  alias Itest.Poller
  alias Itest.StandardExitClient
  alias Itest.InFlightExitClient

  @finality_margin_by_blocks 12

  @default_timeout 30_000

  scenario_timeouts(fn _feature, scenario ->
    case scenario.name do
      "Alice sends Bob funds" -> @default_timeout * 2
      "Alice starts a Standard Exit" -> @default_timeout * 10
      "Alice starts an In Flight Exit" -> @default_timeout * 30
      _ -> @default_timeout
    end
  end)

  scenario_starting_state(fn _ ->
    {:ok, [{alice, alice_pkey}, {bob, bob_pkey}]} = Account.take_accounts(2)

    %{
      alice: %{address: alice, key: alice_pkey},
      bob: %{address: bob, key: bob_pkey}
    }
  end)

  when_(~r/^(?<owner>\w+) deposits "(?<amount>[^"]+)" ETH$/, &deposits/2)

  when_(~r/^(?<sender>\w+) sends (?<receiver>\w+) "(?<amount>[^"]+)" ETH$/, &sends/2)

  when_(~r/^(?<owner>\w+) starts a standard exit$/, &starts_standard_exit/2)

  when_(~r/^(?<owner>\w+) starts an in flight exit$/, &starts_in_flight_exit/2)

  then_(~r/^(?<owner>\w+) should have "(?<amount>[^"]+)" ETH$/, &balance_for/2)

  then_(~r/^(?<owner>\w+) should have "(?<amount>[^"]+)" ETH after finality margin$/, &balance_after_finality_for/2)

  def deposits(%{} = state, %{owner: owner, amount: amount}) do
    %{address: address} = get_account(owner, state)

    {:ok, _receipt_hash} =
      amount
      |> Currency.to_wei()
      |> Client.deposit(address, Account.vault())

    {:ok, state}
  end

  def sends(%{} = state, %{sender: sender, receiver: receiver, amount: amount}) do
    %{address: sender_address, key: sender_key} = get_account(sender, state)
    %{address: receiver_address} = get_account(receiver, state)

    {:ok, [sign_hash, typed_data, _txbytes]} =
      Client.create_transaction(Currency.to_wei(amount), sender_address, receiver_address)

    _ = Client.submit_transaction(typed_data, sign_hash, sender_key)

    {:ok, state}
  end

  def balance_for(%{} = state, %{owner: owner, amount: amount}) do
    %{address: address} = get_account(owner, state)

    expecting_amount = Currency.to_wei(amount)
    response = Poller.pull_balance_until_amount(address, expecting_amount)
    balance = if response == [], do: 0, else: response["amount"]

    assert expecting_amount == balance, "Expecting #{owner} balance to be #{expecting_amount}, was #{balance}"

    {:ok, state}
  end

  def balance_after_finality_for(state, arguments) do
    # Ganache has the `blockTime` set to 0.5sec(500ms), so we wait 0.5 secs for
    # each finality margin block before checking balance and add 5 secs to pad
    # for delays.
    Process.sleep(@finality_margin_by_blocks * 500 + 5_000)
    balance_for(state, arguments)
  end

  def starts_standard_exit(%{} = state, %{owner: owner}) do
    %{address: address} = get_account(owner, state)
    se = StandardExitClient.start_standard_exit(address)
    state = Map.put_new(state, :standard_exit_total_gas_used, se.total_gas_used)

    {:ok, state}
  end

  def starts_in_flight_exit(%{} = state, %{owner: owner}) do
    %{address: address, key: key} = get_account(owner, state)
    %{address: bob_address} = get_account("Bob", state)

    se = InFlightExitClient.start_in_flight_exit(address, key, bob_address)
    {:ok, state}
  end

  defp get_account(account, %{} = state) do
    key = account |> String.downcase() |> String.to_atom()
    state[key]
  end

  # defp track_account(account) do
  # count beginning balance
  # {:ok, initial_balance} = Client.eth_get_balance(alice_account)
  # {initial_balance, ""} = initial_balance |> String.replace_prefix("0x", "") |> Integer.parse(16)

  # Run function, save receipt and calc gas.

  # gas_used = Client.get_gas_used(receipt_hash)

  # {_, new_state} =
  # Map.get_and_update!(state, :gas, fn current_gas ->
  # {current_gas, current_gas + gas_used}
  # end)
  # re-count balance
  # {:ok, balance_after_deposit} = Client.eth_get_balance(alice_account)
  # {balance_after_deposit, ""} = balance_after_deposit |> String.replace_prefix("0x", "") |> Integer.parse(16)
  # state = Map.put_new(new_state, :alice_ethereum_balance, balance_after_deposit)
  # {:ok, Map.put_new(state, :alice_initial_balance, initial_balance)}
  # end
end

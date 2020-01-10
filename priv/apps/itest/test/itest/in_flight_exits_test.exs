defmodule InFlightExitsTests do
  use Cabbage.Feature, async: false, file: "in_flight_exits.feature"

  require Logger

  alias Itest.Account
  alias Itest.Client
  alias Itest.InFlightExitClient
  alias Itest.Poller
  alias Itest.Transactions.Currency

  setup do
    [{alice_account, alice_pkey}, {bob_account, _bob_pkey}] = Account.take_accounts(2)

    %{alice_account: alice_account, alice_pkey: alice_pkey, bob_account: bob_account, gas: 0}
  end

  defwhen ~r/^Alice deposits "(?<amount>[^"]+)" ETH to the network$/,
          %{amount: amount},
          %{alice_account: alice_account} = state do
    {:ok, initial_balance} = Client.eth_get_balance(alice_account)
    {initial_balance, ""} = initial_balance |> String.replace_prefix("0x", "") |> Integer.parse(16)

    {:ok, receipt_hash} =
      amount
      |> Currency.to_wei()
      |> Client.deposit(alice_account, Itest.Account.vault(Currency.ether()))

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

  defthen ~r/^Alice should have "(?<amount>[^"]+)" ETH on the network after finality margin$/,
          %{amount: amount},
          %{alice_account: alice_account} = state do
    _ = Logger.info("Alice should have #{amount} ETH on the network after finality margin")

    case amount do
      "0" ->
        assert Client.get_balance(alice_account, Currency.to_wei(amount)) == []

      _ ->
        %{"amount" => network_amount} = Client.get_balance(alice_account, Currency.to_wei(amount))
        assert network_amount == Currency.to_wei(amount)
    end

    {:ok, balance} = Client.eth_get_balance(alice_account)
    {balance, ""} = balance |> String.replace_prefix("0x", "") |> Integer.parse(16)
    {:ok, Map.put(state, :alice_ethereum_balance, balance)}
  end

  defwhen ~r/Alice starts an in flight exit$/,
          _,
          %{
            alice_account: alice_account,
            alice_pkey: alice_pkey,
            bob_account: bob_account
          } = state do
    _ife = InFlightExitClient.start_in_flight_exit(alice_account, alice_pkey, bob_account)

    {:ok, state}
  end

  defthen ~r/Alice should have "(?<amount>[^"]+)" ETH after finality margin$/,
          %{amount: amount},
          %{alice_account: alice_account} = state do
    expecting_amount = Currency.to_wei(amount)
    response = Poller.pull_balance_until_amount(alice_account, expecting_amount)
    balance = if response == [], do: 0, else: response["amount"]

    assert expecting_amount == balance, "Expecting #{alice_account} balance to be #{expecting_amount}, was #{balance}"

    {:ok, state}
  end
end

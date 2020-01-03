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
  alias Itest.Poller
  # TODO Fix this, expose via API, also its 12 blocks
  # @finality_margin_by_blocks 12
  @default_timeout 60_000
  scenario_timeouts(fn _feature, _scenario -> @default_timeout * 10 end)

  scenario_starting_state(fn _ ->
    {:ok, _} =
      Itest.Eventer.start_link(
        ws_url: "ws://127.0.0.1:8546",
        name: :plasma_framework,
        listen_to: %{"address" => Itest.Account.plasma_framework()},
        abi_path: Path.join([File.cwd!(), "../data/plasma-contracts/contracts/", "PlasmaFramework.json"])
      )

    {:ok, _} =
      Itest.Eventer.start_link(
        ws_url: "ws://127.0.0.1:8546",
        name: :eth_vault,
        listen_to: %{"address" => Itest.Account.vault(Currency.ether())},
        abi_path: Path.join([File.cwd!(), "../data/plasma-contracts/contracts/", "EthVault.json"])
      )

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

  then_(
    ~r/^Alice should have "(?<amount>[^"]+)" ETH on the network after finality margin$/,
    fn %{alice_account: alice_account} = state, %{amount: amount} ->
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

  # IFE
  when_(~r/Alice starts an in flight exit$/, fn %{
                                                  alice_account: alice_account,
                                                  alice_pkey: alice_pkey,
                                                  bob_account: bob_account
                                                } = state,
                                                _ ->
    _ife = InFlightExitClient.start_in_flight_exit(alice_account, alice_pkey, bob_account)

    {:ok, state}
  end)

  # IFE
  then_(~r/Alice should have "(?<amount>[^"]+)" ETH after finality margin$/, fn %{alice_account: alice_account} = state,
                                                                                %{amount: amount} ->
    # Process.sleep(@finality_margin_by_blocks * 500 + 120_000)
    expecting_amount = Currency.to_wei(amount)
    response = Poller.pull_balance_until_amount(alice_account, expecting_amount)
    balance = if response == [], do: 0, else: response["amount"]

    assert expecting_amount == balance, "Expecting #{alice_account} balance to be #{expecting_amount}, was #{balance}"

    {:ok, state}
  end)

  defp assert_equal(left, right) do
    assert_equal(left, right, "")
  end

  defp assert_equal(left, right, message) do
    assert(left == right, "Expected #{left}, but have #{right}." <> message)
  end
end

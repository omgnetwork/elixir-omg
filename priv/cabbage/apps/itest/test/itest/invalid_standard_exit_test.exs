defmodule InvalidStandardExitsTests do
  use Cabbage.Feature, async: false, file: "invalid_standard_exits.feature"

  require Logger

  alias Itest.Account
  alias Itest.ApiModel.Utxo
  alias Itest.Client
  alias Itest.StandardExitChallengeClient
  alias Itest.StandardExitClient
  alias Itest.Transactions.Currency
  alias WatcherSecurityCriticalAPI.Api.Status

  import Itest.Poller, only: [pull_api_until_successful: 3, pull_api_until_successful: 4]

  @retry_count 60
  @sleep_retry_sec 5_000

  # FIXME: consider applying in other files
  defp all?(expected_events), do: all?(expected_events, @retry_count)
  defp all?(_, 0), do: false

  defp all?(expected_events, counter) do
    byzantine_events =
      pull_api_until_successful(Status, :status_get, WatcherSecurityCriticalAPI.Connection.new())
      |> Map.fetch!("byzantine_events")
      |> Enum.map(& &1["event"])

    if Enum.sort(byzantine_events) == Enum.sort(expected_events) do
      true
    else
      Process.sleep(@sleep_retry_sec)
      all?(expected_events, counter - 1)
    end
  end

  setup do
    [{alice_account, alice_pkey}, {bob_account, _bob_pkey}] = Account.take_accounts(2)

    %{alice_account: alice_account, alice_pkey: alice_pkey, bob_account: bob_account, gas: 0}
  end

  defwhen ~r/^Alice deposits "(?<amount>[^"]+)" ETH to the root chain$/,
          %{amount: amount},
          %{alice_account: alice_account} = state do
    initial_balance = Itest.Poller.eth_get_balance(alice_account)

    {:ok, receipt_hash} =
      amount
      |> Currency.to_wei()
      |> Client.deposit(alice_account, Itest.Account.vault(Currency.ether()))

    gas_used = Client.get_gas_used(receipt_hash)

    new_state =
      state
      |> Map.put_new(:alice_gas, gas_used)
      |> Map.put_new(:alice_initial_balance, initial_balance)

    {:ok, new_state}
  end

  defthen ~r/^Alice should have "(?<amount>[^"]+)" ETH on the child chain$/,
          %{amount: amount},
          %{alice_account: alice_account} = state do
    expecting_amount = Currency.to_wei(amount)
    %{"amount" => balance} = Client.get_balance(alice_account, expecting_amount)
    assert expecting_amount == balance

    {:ok, state}
  end

  defthen ~r/^Alice should have no more than "(?<amount>[^"]+)" ETH on the child chain$/,
          %{amount: amount},
          %{alice_account: alice_account} = state do
    expecting_amount = Currency.to_wei(amount)
    # FIXME: can this be that sometimes get_balance returns an array, sometimes not. Workaround:
    [%{"amount" => balance}] =
      case Client.get_balance(alice_account) do
        [%{"amount" => balance}] -> [%{"amount" => balance}]
        %{"amount" => balance} -> [%{"amount" => balance}]
      end

    assert expecting_amount >= balance

    {:ok, state}
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

    _ = Client.submit_transaction(typed_data, sign_hash, [alice_pkey])

    {:ok, Map.put_new(state, :alice_recently_spent_utxo_pos, alice_recently_spent_utxo_pos)}
  end

  # FIXME move
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

  defwhen ~r/^Some state of the chain$/,
          _,
          state do
    status = pull_api_until_successful(Status, :status_get, WatcherSecurityCriticalAPI.Connection.new())
    {:ok, Map.put(state, :prior_byzantine_events, status["byzantine_events"])}
  end

  defwhen ~r/^Alice starts a standard exit on the child chain from her recently spent input$/,
          _,
          %{alice_account: alice_account, alice_recently_spent_utxo_pos: alice_recently_spent_utxo_pos} = state do
    se =
      %StandardExitClient{address: alice_account, utxo: alice_recently_spent_utxo_pos}
      |> StandardExitClient.start_standard_exit()

    gas_used1 = Client.get_gas_used(se.start_standard_exit_hash)
    gas_used2 = Client.get_gas_used(se.add_exit_queue_hash)

    new_state =
      state
      |> Map.update!(:alice_gas, fn current_gas -> current_gas + gas_used1 + gas_used2 end)
      |> Map.put_new(:alice_bond, se.standard_exit_bond_size)

    {:ok, new_state}
  end

  # FIXME: change to "challenges it"
  defwhen ~r/^Bob detects the new "(?<event>[^"]+)" and challenges all$/,
          %{event: event},
          %{bob_account: bob_account, prior_byzantine_events: prior_byzantine_events} = state do
    prior_byzantine_events_names = Enum.map(prior_byzantine_events, & &1["event"])
    assert all?([event | prior_byzantine_events_names])

    pull_api_until_successful(Status, :status_get, WatcherSecurityCriticalAPI.Connection.new())
    |> Map.fetch!("byzantine_events")
    |> Enum.filter(&(&1["event"] == "invalid_exit"))
    |> Enum.map(& &1["details"]["utxo_pos"])
    |> Enum.map(&StandardExitChallengeClient.challenge_standard_exit(bob_account, &1))

    {:ok, state}
  end

  defthen ~r/^The child chain is secure$/,
          _,
          %{} = state do
    assert all?([])
    {:ok, state}
  end

  defthen ~r/^Alice tries to process exits$/, _, %{alice_account: alice_account} = state do
    se =
      %StandardExitClient{address: alice_account, standard_exit_id: 0}
      |> StandardExitClient.wait_and_process_standard_exit()

    gas_used = Client.get_gas_used(se.process_exit_receipt_hash)
    new_state = Map.update!(state, :alice_gas, fn current_gas -> current_gas + gas_used end)

    {:ok, new_state}
  end

  defthen ~r/^Alice should have "(?<difference>[^"]+)" ETH less on the blockchain$/,
          %{difference: difference},
          %{
            alice_initial_balance: alice_initial_balance,
            alice_account: alice_account,
            alice_gas: alice_gas,
            alice_bond: alice_bond
          } = state do
    alice_ethereum_balance = Itest.Poller.eth_get_balance(alice_account)
    assert alice_ethereum_balance == alice_initial_balance - Currency.to_wei(difference) - alice_gas - alice_bond

    {:ok, state}
  end
end

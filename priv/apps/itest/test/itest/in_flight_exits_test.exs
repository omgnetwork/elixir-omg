defmodule InFlightExitsTests do
  use Cabbage.Feature, async: false, file: "in_flight_exits.feature"

  require Logger

<<<<<<< HEAD
  alias Itest.Account
  alias Itest.Client
  alias Itest.InFlightExitClient
  alias Itest.Poller
  alias Itest.Transactions.Currency

  setup do
    [{alice_account, alice_pkey}, {bob_account, _bob_pkey}] = Account.take_accounts(2)

    %{alice_account: alice_account, alice_pkey: alice_pkey, bob_account: bob_account, gas: 0}
  end

  defwhen ~r/^Alice deposits "(?<amount>[^"]+)" ETH to the root chain$/,
          %{amount: amount},
          %{alice_account: alice_account} = state do
    initial_balance = Itest.Poller.eth_get_balance(alice_account)
=======
  alias ExPlasma.Transactions.Payment
  alias Itest.Account
  alias Itest.ApiModel.IfeExitData
  alias Itest.ApiModel.IfeExits
  alias Itest.ApiModel.IfeInputChallenge
  alias Itest.ApiModel.IfeOutputChallenge
  alias Itest.ApiModel.SubmitTransactionResponse
  alias Itest.Client
  alias Itest.Transactions.Currency
  alias Itest.Transactions.Encoding
  alias Itest.Transactions.PaymentType
  alias WatcherSecurityCriticalAPI.Api.InFlightExit
  alias WatcherSecurityCriticalAPI.Api.InFlightExit
  alias WatcherSecurityCriticalAPI.Api.Status
  alias WatcherSecurityCriticalAPI.Api.Transaction
  alias WatcherSecurityCriticalAPI.Connection, as: Watcher
  alias WatcherSecurityCriticalAPI.Model.InFlightExitInputChallengeDataBodySchema
  alias WatcherSecurityCriticalAPI.Model.InFlightExitTxBytesBodySchema
  alias WatcherSecurityCriticalAPI.Model.TransactionSubmitBodySchema
  alias WatcherSecurityCriticalAPI.Model.InFlightExitOutputChallengeDataBodySchema

  import Itest.Poller,
    only: [
      pull_for_utxo_until_recognized_deposit: 4,
      pull_api_until_successful: 3,
      pull_api_until_successful: 4,
      wait_on_receipt_confirmed: 1
    ]

  @ife_gas 2_000_000
  @ife_gas_price 1_000_000_000
  @gas_piggyback 1_000_000
  @gas_add_exit_queue 800_000
  @retry_count 60
  @sleep_retry_sec 5_000
  setup do
    {:ok, _} =
      Itest.ContractEvent.start_link(
        ws_url: "ws://127.0.0.1:8546",
        name: :eth_vault,
        listen_to: %{"address" => Itest.Account.vault(Currency.ether())},
        abi_path: Path.join([File.cwd!(), "../../../data/plasma-contracts/contracts/", "EthVault.json"]),
        subscribe: self()
      )

    # {:ok, _} =
    #   Itest.ContractEvent.start_link(
    #     ws_url: "ws://127.0.0.1:8546",
    #     name: :payment_exit_game,
    #     listen_to: %{"address" => Itest.Account.vault(Currency.ether())},
    #     abi_path: Path.join([File.cwd!(), "../../../data/plasma-contracts/contracts/", "PaymentExitGame.json"]),
    #     subscribe: self()
    #   )

    [{alice_address, alice_pkey}, {bob_address, bob_pkey}] = Account.take_accounts(2)

    %{
      "exit_game_contract_address" => get_exit_game_contract_address(),
      "in_flight_exit_bond_size" => get_in_flight_exit_bond_size(get_exit_game_contract_address()),
      "piggyback_bond_size" => get_piggyback_bond_size(get_exit_game_contract_address()),
      "Alice" => %{
        address: alice_address,
        pkey: "0x" <> alice_pkey,
        gas: 0,
        ethereum_balance: 0,
        ethereum_initial_balance: 0,
        omg_network_balance: 0,
        utxos: [],
        exit_data: nil,
        transaction_submit: nil,
        receipt_hashes: [],
        in_flight_exit_id: nil,
        in_flight_exit_ids: nil
      },
      "Bob" => %{
        address: bob_address,
        pkey: "0x" <> bob_pkey,
        gas: 0,
        ethereum_balance: 0,
        ethereum_initial_balance: 0,
        omg_network_balance: 0,
        utxos: [],
        exit_data: nil,
        transaction_submit: nil,
        receipt_hashes: [],
        in_flight_exit_id: nil,
        in_flight_exit_ids: nil
      }
    }
  end

  defwhen ~r/^"(?<entity>[^"]+)" deposits "(?<amount>[^"]+)" ETH to the network$/,
          %{entity: entity, amount: amount},
          state do
    %{address: address} = entity_state = state[entity]
    {:ok, initial_balance} = Client.eth_get_balance(address)
    {initial_balance, ""} = initial_balance |> String.replace_prefix("0x", "") |> Integer.parse(16)
>>>>>>> feature: introduce cabbage

    {:ok, receipt_hash} =
      amount
      |> Currency.to_wei()
<<<<<<< HEAD
      |> Client.deposit(alice_account, Itest.Account.vault(Currency.ether()))

    gas_used = Client.get_gas_used(receipt_hash)

    {_, new_state} =
      Map.get_and_update!(state, :gas, fn current_gas ->
        {current_gas, current_gas + gas_used}
      end)

    balance_after_deposit = Itest.Poller.eth_get_balance(alice_account)

    state = Map.put_new(new_state, :alice_ethereum_balance, balance_after_deposit)
    {:ok, Map.put_new(state, :alice_initial_balance, initial_balance)}
  end

  defthen ~r/^Alice should have "(?<amount>[^"]+)" ETH on the root chain after finality margin$/,
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

    balance = Itest.Poller.eth_get_balance(alice_account)

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
=======
      |> Client.deposit(address, Itest.Account.vault(Currency.ether()))

    # retrieve finality margin from the API
    geth_block_every = 1
    finality_margin_blocks = 6
    to_miliseconds = 1000

    finality_margin_blocks
    |> Kernel.*(geth_block_every)
    |> Kernel.*(to_miliseconds)
    |> Kernel.round()
    |> Process.sleep()

    {:ok, balance_after_deposit} = Client.eth_get_balance(address)
    {balance_after_deposit, ""} = balance_after_deposit |> String.replace_prefix("0x", "") |> Integer.parse(16)

    entity_state =
      entity_state
      |> Map.put(:ethereum_balance, balance_after_deposit)
      |> Map.put(:ethereum_initial_balance, initial_balance)
      |> Map.put(:receipt_hashes, [receipt_hash | entity_state.receipt_hashes])

    {:ok, Map.put(state, entity, entity_state)}
  end

  defthen ~r/^"(?<entity>[^"]+)" should have "(?<amount>[^"]+)" ETH on the network after finality margin$/,
          %{entity: entity, amount: amount},
          state do
    %{address: address} = entity_state = state[entity]
    _ = Logger.info("#{entity} should have #{amount} ETH on the network after finality margin")

    omg_network_balance =
      case amount do
        "0" ->
          assert Client.get_balance(address, Currency.to_wei(amount)) == []
          0

        _ ->
          %{"amount" => network_amount} = Client.get_balance(address, Currency.to_wei(amount))
          assert network_amount == Currency.to_wei(amount)
          network_amount
      end

    blknum = capture_blknum_from_event(address, amount)

    all_utxos =
      pull_for_utxo_until_recognized_deposit(
        address,
        Currency.to_wei(amount),
        Encoding.to_hex(Currency.ether()),
        blknum
      )

    {:ok, balance} = Client.eth_get_balance(address)
    {balance, ""} = balance |> String.replace_prefix("0x", "") |> Integer.parse(16)

    entity_state =
      entity_state
      |> Map.put(:ethereum_balance, balance)
      |> Map.put(:utxos, all_utxos["data"])
      |> Map.put(:omg_network_balance, omg_network_balance)

    {:ok, Map.put(state, entity, entity_state)}
  end

  # alice creates a transaction sending 5 eth to bob (creates! not sends!)
  # submitted_tx =
  #   OMG.TestHelper.create_signed(
  #     [{alice_deposit_blknum, txindex, oindex, alice}, {bob_deposit_blknum, txindex, oindex, bob}],
  #     @eth,
  #     [{alice, 5}, {bob, 15}]
  #   )
  defwhen ~r/Alice creates a transaction for "(?<amount>[^"]+)" ETH$/,
          %{amount: amount},
          state do
    amount = Currency.to_wei(amount)

    %{address: alice_address, utxos: alice_utxos, pkey: alice_pkey, omg_network_balance: alice_omg_network_balance} =
      alice_state = state["Alice"]

    %{address: bob_address, utxos: bob_utxos, pkey: bob_pkey, omg_network_balance: bob_omg_network_balance} =
      state["Bob"]

    # inputs
    alice_deposit_utxo = hd(alice_utxos)

    alice_deposit_input = %ExPlasma.Utxo{
      blknum: alice_deposit_utxo["blknum"],
      currency: Currency.ether(),
      oindex: 0,
      txindex: 0,
      output_type: 1,
      owner: alice_address
    }

    bob_deposit_utxo = hd(bob_utxos)

    bob_deposit_input = %ExPlasma.Utxo{
      blknum: bob_deposit_utxo["blknum"],
      currency: Currency.ether(),
      oindex: 0,
      txindex: 0,
      output_type: 1,
      owner: bob_address
    }

    # outputs
    alice_output = %ExPlasma.Utxo{
      currency: Currency.ether(),
      owner: alice_address,
      amount: alice_omg_network_balance - Currency.to_wei(5)
    }

    bob_output = %ExPlasma.Utxo{
      currency: Currency.ether(),
      owner: bob_address,
      amount: amount + bob_omg_network_balance
    }

    transaction = %Payment{inputs: [alice_deposit_input, bob_deposit_input], outputs: [alice_output, bob_output]}

    submitted_tx =
      ExPlasma.Transaction.sign(transaction,
        keys: [alice_pkey, bob_pkey]
      )

    txbytes = ExPlasma.Transaction.encode(submitted_tx)

    ## we need to duplicate the transaction because we need an unsigned one later!
    unsigned_submitted_tx =
      ExPlasma.Transaction.sign(transaction,
        keys: []
      )

    unsigned_txbytes = ExPlasma.Transaction.encode(unsigned_submitted_tx)

    alice_state =
      alice_state
      |> Map.put(:submitted_tx, submitted_tx)
      |> Map.put(:txbytes, txbytes)
      |> Map.put(:unsigned_submitted_tx, unsigned_submitted_tx)
      |> Map.put(:unsigned_txbytes, unsigned_txbytes)

    entity = "Alice"
    {:ok, Map.put(state, entity, alice_state)}
  end

  defthen ~r/Bob gets in flight exit data for "(?<amount>[^"]+)" ETH$/, %{amount: amount}, state do
    amount = Currency.to_wei(amount)
    %{address: bob_address, utxos: bob_utxos, pkey: bob_pkey} = bob_state = state["Bob"]

    # inputs
    bob_deposit_utxo = hd(bob_utxos)

    bob_deposit_input = %ExPlasma.Utxo{
      blknum: bob_deposit_utxo["blknum"],
      currency: Currency.ether(),
      oindex: 0,
      txindex: 0,
      output_type: 1,
      owner: bob_address
    }

    # outputs
    bob_output = %ExPlasma.Utxo{
      currency: Currency.ether(),
      owner: bob_address,
      amount: amount
    }

    transaction = %Payment{inputs: [bob_deposit_input], outputs: [bob_output]}

    submitted_tx =
      ExPlasma.Transaction.sign(transaction,
        keys: [bob_pkey]
      )

    txbytes = ExPlasma.Transaction.encode(submitted_tx)

    payload = %InFlightExitTxBytesBodySchema{txbytes: Encoding.to_hex(txbytes)}
    response = pull_api_until_successful(InFlightExit, :in_flight_exit_get_data, Watcher.new(), payload)
    exit_data = IfeExitData.to_struct(response)
    bob_state = Map.put(bob_state, :exit_data, exit_data)

    entity = "Bob"
    {:ok, Map.put(state, entity, bob_state)}
  end

  defthen ~r/Alice sends a transaction$/, _, state do
    %{txbytes: txbytes} = alice_state = state["Alice"]

    transaction_submit_body_schema = %TransactionSubmitBodySchema{transaction: Encoding.to_hex(txbytes)}
    {:ok, response} = Transaction.submit(Watcher.new(), transaction_submit_body_schema)

    submit_transaction_response =
      response
      |> Map.get(:body)
      |> Jason.decode!()
      |> Map.get("data")
      |> SubmitTransactionResponse.to_struct()

    alice_state = Map.put(alice_state, :transaction_submit, submit_transaction_response)

    entity = "Alice"

    {:ok, Map.put(state, entity, alice_state)}
  end

  defwhen ~r/Bob sends a transaction spending Alices output$/, _, state do
    %{address: alice_address, transaction_submit: alice_transaction_submit} = state["Alice"]

    %{address: bob_address, pkey: bob_pkey} = bob_state = state["Bob"]

    # inputs
    bob_input = %ExPlasma.Utxo{
      blknum: alice_transaction_submit.blknum,
      currency: Currency.ether(),
      oindex: 1,
      txindex: 0,
      output_type: 1,
      owner: bob_address
    }

    # outputs
    alice_output1 = %ExPlasma.Utxo{
      currency: Currency.ether(),
      owner: alice_address,
      amount: Currency.to_wei(2)
    }

    alice_output2 = %ExPlasma.Utxo{
      currency: Currency.ether(),
      owner: alice_address,
      amount: Currency.to_wei(3)
    }

    transaction = %Payment{inputs: [bob_input], outputs: [alice_output1, alice_output2]}

    submitted_tx =
      ExPlasma.Transaction.sign(transaction,
        keys: [bob_pkey]
      )

    txbytes = ExPlasma.Transaction.encode(submitted_tx)
    transaction_submit_body_schema = %TransactionSubmitBodySchema{transaction: Encoding.to_hex(txbytes)}
    {:ok, response} = Transaction.submit(Watcher.new(), transaction_submit_body_schema)

    submit_transaction_response =
      response
      |> Map.get(:body)
      |> Jason.decode!()
      |> Map.get("data")
      |> SubmitTransactionResponse.to_struct()

    bob_state =
      bob_state
      |> Map.put(:submitted_tx, submitted_tx)
      |> Map.put(:txbytes, txbytes)
      |> Map.put(:transaction_submit, submit_transaction_response)

    entity = "Bob"
    {:ok, Map.put(state, entity, bob_state)}
  end

  defwhen ~r/Alice starts an in flight exit$/, _, state do
    exit_game_contract_address = state["exit_game_contract_address"]
    in_flight_exit_bond_size = state["in_flight_exit_bond_size"]
    %{address: address, txbytes: txbytes} = alice_state = state["Alice"]
    payload = %InFlightExitTxBytesBodySchema{txbytes: Encoding.to_hex(txbytes)}
    response = pull_api_until_successful(InFlightExit, :in_flight_exit_get_data, Watcher.new(), payload)
    exit_data = IfeExitData.to_struct(response)
    receipt_hash = do_in_flight_exit(exit_game_contract_address, in_flight_exit_bond_size, address, exit_data)

    alice_state =
      alice_state
      |> Map.put(:exit_data, exit_data)
      |> Map.put(:receipt_hashes, [receipt_hash | alice_state.receipt_hashes])

    entity = "Alice"
    {:ok, Map.put(state, entity, alice_state)}
  end

  defwhen ~r/Alice verifies its in flight exit$/, _, state do
    exit_game_contract_address = state["exit_game_contract_address"]
    %{exit_data: exit_data} = alice_state = state["Alice"]

    in_flight_exit_id = get_in_flight_exit_id(exit_game_contract_address, exit_data)
    in_flight_exit_ids = get_in_flight_exits(exit_game_contract_address, in_flight_exit_id)
    assert in_flight_exit_ids.exit_map == 0

    alice_state =
      alice_state
      |> Map.put(:in_flight_exit_id, in_flight_exit_id)
      |> Map.put(:in_flight_exit_ids, in_flight_exit_ids)

    entity = "Alice"
    {:ok, Map.put(state, entity, alice_state)}
  end

  defthen ~r/Bob piggybacks inputs and outputs from Alice$/, _, state do
    exit_game_contract_address = state["exit_game_contract_address"]
    piggyback_bond_size = state["piggyback_bond_size"]
    %{exit_data: exit_data, in_flight_exit_id: in_flight_exit_id} = state["Alice"]
    %{address: address} = bob_state = state["Bob"]
    output_index = 1
    input_index = 1
    # we need to add a vault queue for this currency first
    receipt_hash_0 = add_exit_queue(address)
    receipt_hash_1 = piggyback_output(exit_game_contract_address, piggyback_bond_size, address, output_index, exit_data)
    receipt_hash_2 = piggyback_input(exit_game_contract_address, piggyback_bond_size, address, input_index, exit_data)

    bob_state =
      Map.put(
        bob_state,
        :receipt_hashes,
        Enum.concat([receipt_hash_0, receipt_hash_1, receipt_hash_2], bob_state.receipt_hashes)
      )

    in_flight_exit_ids = get_in_flight_exits(exit_game_contract_address, in_flight_exit_id)
    # bits is flagged when output is piggybacked
    assert in_flight_exit_ids.exit_map != 0
    entity = "Bob"
    {:ok, Map.put(state, entity, bob_state)}
  end

  # ### start the competing IFE, to double-spend some inputs
  defthen ~r/Bob starts a competing in flight exit$/, _, state do
    exit_game_contract_address = state["exit_game_contract_address"]
    in_flight_exit_bond_size = state["in_flight_exit_bond_size"]
    %{address: address, exit_data: exit_data} = bob_state = state["Bob"]

    receipt_hash = do_in_flight_exit(exit_game_contract_address, in_flight_exit_bond_size, address, exit_data)

    bob_state = Map.put(bob_state, :receipt_hashes, [receipt_hash | bob_state.receipt_hashes])

    entity = "Bob"
    {:ok, Map.put(state, entity, bob_state)}
  end

  # ### start the competing IFE, to double-spend some inputs
  defthen ~r/Alice starts to challenge Bobs in flight exit$/, _, state do
    exit_game_contract_address = state["exit_game_contract_address"]

    %{
      address: address,
      in_flight_exit_id: in_flight_exit_id,
      in_flight_exit_ids: in_flight_exit_ids,
      unsigned_txbytes: unsigned_txbytes
    } = alice_state = state["Alice"]

    # only a single non_canonical event, since on of the IFE tx is included!
    # only piggyback_available for tx2 is present, tx1 is included in block and does not spawn that event
    assert check_if_byzantine_events_present(["invalid_piggyback", "non_canonical_ife", "piggyback_available"]) == true

    payload = %InFlightExitInputChallengeDataBodySchema{txbytes: Encoding.to_hex(unsigned_txbytes), input_index: 1}
    response = pull_api_until_successful(InFlightExit, :in_flight_exit_get_input_challenge_data, Watcher.new(), payload)
    ife_input_challenge = IfeInputChallenge.to_struct(response)
    assert ife_input_challenge.in_flight_txbytes == Encoding.to_hex(unsigned_txbytes)
    receipt_hash_0 = challenge_in_flight_exit_input_spent(exit_game_contract_address, address, ife_input_challenge)
    # sanity check
    in_flight_exit_ids1 = get_in_flight_exits(exit_game_contract_address, in_flight_exit_id)
    assert in_flight_exit_ids1.exit_map != in_flight_exit_ids.exit_map
    assert in_flight_exit_ids1.exit_map != 0

    # output challenge 
    payload = %InFlightExitOutputChallengeDataBodySchema{txbytes: Encoding.to_hex(unsigned_txbytes), output_index: 1}

    response =
      pull_api_until_successful(InFlightExit, :in_flight_exit_get_output_challenge_data, Watcher.new(), payload)

    ife_output_challenge = IfeOutputChallenge.to_struct(response)
    assert ife_output_challenge.in_flight_txbytes == Encoding.to_hex(unsigned_txbytes)
    receipt_hash_1 = challenge_in_flight_exit_output_spent(exit_game_contract_address, address, ife_output_challenge)
    # observe the result - piggybacks are gone
    in_flight_exit_ids2 = get_in_flight_exits(exit_game_contract_address, in_flight_exit_id)
    assert in_flight_exit_ids2.exit_map == 0

    # observe the byzantine events gone
    # but how do I remove these??? cleanup!
    assert check_if_byzantine_events_present(["non_canonical_ife", "piggyback_available"]) == true

    alice_state =
      Map.put(
        alice_state,
        :receipt_hashes,
        Enum.concat([receipt_hash_0, receipt_hash_1], alice_state.receipt_hashes)
      )

    entity = "Alice"

    {:ok, Map.put(state, entity, alice_state)}
  end

  ###############################################################################################
  #### PRIVATE
  ###############################################################################################
  defp check_if_byzantine_events_present(events), do: check_if_byzantine_events_present(Enum.sort(events), @retry_count)
  defp check_if_byzantine_events_present(_, 0), do: false

  defp check_if_byzantine_events_present(events, counter) do
    result =
      case pull_api_until_successful(Status, :status_get, Watcher.new()) do
        %{"byzantine_events" => byzantine_events} ->
          byzantine_events =
            byzantine_events
            |> Enum.map_reduce([], fn
              %{"event" => event}, acc -> {byzantine_events, [event | acc]}
              _, acc -> {byzantine_events, acc}
            end)
            |> elem(1)
            |> Enum.sort()

          IO.inspect(byzantine_events)
          byzantine_events == events

        _ ->
          false
      end

    case result do
      true ->
        result

      false ->
        Process.sleep(@sleep_retry_sec)
        check_if_byzantine_events_present(events, counter - 1)
    end
  end

  defp challenge_in_flight_exit_input_spent(exit_game_contract_address, address, ife_input_challenge) do
    values = [
      {Encoding.to_binary(ife_input_challenge.in_flight_txbytes), ife_input_challenge.in_flight_input_index,
       Encoding.to_binary(ife_input_challenge.spending_txbytes), ife_input_challenge.spending_input_index,
       Encoding.to_binary(ife_input_challenge.spending_sig), Encoding.to_binary(ife_input_challenge.input_tx),
       ife_input_challenge.input_utxo_pos}
    ]

    data =
      ABI.encode(
        "challengeInFlightExitInputSpent((bytes,uint16,bytes,uint16,bytes,bytes,uint256))",
        values
      )

    txmap = %{
      from: address,
      to: exit_game_contract_address,
      value: Encoding.to_hex(0),
      data: Encoding.to_hex(data),
      gas: Encoding.to_hex(@ife_gas * 2),
      gasPrice: Encoding.to_hex(@ife_gas_price)
    }

    {:ok, receipt_hash} = Ethereumex.HttpClient.eth_send_transaction(txmap)
    _ = Logger.info("Done IFE with hash #{receipt_hash}")
    wait_on_receipt_confirmed(receipt_hash)

    receipt_hash
  end

  defp challenge_in_flight_exit_output_spent(exit_game_contract_address, address, ife_output_challenge) do
    values = [
      {Encoding.to_binary(ife_output_challenge.in_flight_txbytes),
       Encoding.to_binary(ife_output_challenge.in_flight_proof), ife_output_challenge.in_flight_output_pos,
       Encoding.to_binary(ife_output_challenge.spending_txbytes), ife_output_challenge.spending_input_index,
       Encoding.to_binary(ife_output_challenge.spending_sig)}
    ]

    data =
      ABI.encode(
        "challengeInFlightExitOutputSpent((bytes,bytes,uint256,bytes,uint16,bytes))",
        values
      )

    txmap = %{
      from: address,
      to: exit_game_contract_address,
      value: Encoding.to_hex(0),
      data: Encoding.to_hex(data),
      gas: Encoding.to_hex(@ife_gas * 2),
      gasPrice: Encoding.to_hex(@ife_gas_price)
    }

    {:ok, receipt_hash} = Ethereumex.HttpClient.eth_send_transaction(txmap)
    _ = Logger.info("Done IFE with hash #{receipt_hash}")
    wait_on_receipt_confirmed(receipt_hash)

    receipt_hash
  end

  # This takes all the data we get from the Watcher to start an in flight exit.
  # Since we get it as a hex string, we convert it back to binary so that we can
  # ABI encode the data and send it back to the contract to start the in flight exit.
  defp do_in_flight_exit(exit_game_contract_address, in_flight_exit_bond_size, address, exit_data) do
    in_flight_tx = Encoding.to_binary(exit_data.in_flight_tx)
    in_flight_tx_sigs = Enum.map(exit_data.in_flight_tx_sigs, &Encoding.to_binary(&1))
    input_txs = Enum.map(exit_data.input_txs, &Encoding.to_binary(&1))
    input_txs_inclusion_proofs = Enum.map(exit_data.input_txs_inclusion_proofs, &Encoding.to_binary(&1))
    input_utxos_pos = Enum.map(exit_data.input_utxos_pos, &:binary.encode_unsigned(&1))

    values = [
      {in_flight_tx, input_txs, input_utxos_pos, input_txs_inclusion_proofs, in_flight_tx_sigs}
    ]

    data =
      ABI.encode(
        "startInFlightExit((bytes,bytes[],uint256[],bytes[],bytes[]))",
        values
      )

    txmap = %{
      from: address,
      to: exit_game_contract_address,
      value: Encoding.to_hex(in_flight_exit_bond_size),
      data: Encoding.to_hex(data),
      gas: Encoding.to_hex(@ife_gas * 2),
      gasPrice: Encoding.to_hex(@ife_gas_price)
    }

    {:ok, receipt_hash} = Ethereumex.HttpClient.eth_send_transaction(txmap)
    _ = Logger.info("Done IFE with hash #{receipt_hash}")
    wait_on_receipt_confirmed(receipt_hash)

    receipt_hash
  end

  defp get_in_flight_exit_id(exit_game_contract_address, exit_data) do
    _ = Logger.info("Get in flight exit id...")
    txbytes = Encoding.to_binary(exit_data.in_flight_tx)
    data = ABI.encode("getInFlightExitId(bytes)", [txbytes])
    {:ok, result} = Ethereumex.HttpClient.eth_call(%{to: exit_game_contract_address, data: Encoding.to_hex(data)})

    ife_exit_id =
      result
      |> Encoding.to_binary()
      |> ABI.TypeDecoder.decode([{:uint, 128}])
      |> hd()

    _ = Logger.warn("IFE id is #{ife_exit_id}")

    ife_exit_id
  end

  defp get_in_flight_exits(exit_game_contract_address, ife_exit_id) do
    _ = Logger.info("Get in flight exits...")
    data = ABI.encode("inFlightExits(uint160)", [ife_exit_id])
    {:ok, result} = Ethereumex.HttpClient.eth_call(%{to: exit_game_contract_address, data: Encoding.to_hex(data)})

    return_struct = [
      :bool,
      {:uint, 64},
      {:uint, 256},
      {:uint, 256},
      # NOTE: there are these two more fields in the return but they can be ommitted,
      #       both have withdraw_data_struct type
      # withdraw_data_struct,
      # withdraw_data_struct,
      :address,
      {:uint, 256},
      {:uint, 256}
    ]

    return_fields = [
      :is_canonical,
      :exit_start_timestamp,
      :exit_map,
      :position,
      :bond_owner,
      :bond_size,
      :oldest_competitor_position
    ]

    ife_exit_ids =
      result
      |> Encoding.to_binary()
      |> ABI.TypeDecoder.decode(return_struct)
      |> IfeExits.to_struct(return_fields)

    _ = Logger.info("IFEs #{inspect(ife_exit_ids)}")
    ife_exit_ids
  end

  defp capture_blknum_from_event(address, amount) do
    receive do
      {:event, {%ABI.FunctionSelector{}, event}} = message ->
        [
          {"depositor", "address", true, event_account},
          {"blknum", "uint256", true, event_blknum},
          {"token", "address", true, event_token},
          {"amount", "uint256", false, event_amount}
        ] = event

        # is this really our deposit?
        # let's double check with what we know
        case {Encoding.to_hex(event_account) == address, Currency.ether() == event_token,
              Currency.to_wei(amount) == event_amount} do
          {true, true, true} ->
            event_blknum

          _ ->
            # listen to some more, maybe we captured some other accounts deposit
            # return the message in the mailbox
            send(self(), message)
            capture_blknum_from_event(event_account, amount)
        end
    after
      5_000 ->
        throw(:deposit_event_didnt_arrive)
    end
  end

  defp get_exit_game_contract_address() do
    data = ABI.encode("exitGames(uint256)", [PaymentType.simple_payment_transaction()])
    {:ok, result} = Ethereumex.HttpClient.eth_call(%{to: Itest.Account.plasma_framework(), data: Encoding.to_hex(data)})

    result
    |> Encoding.to_binary()
    |> ABI.TypeDecoder.decode([:address])
    |> hd()
    |> Encoding.to_hex()
  end

  defp get_in_flight_exit_bond_size(exit_game_contract_address) do
    _ = Logger.info("Trying to get bond size for in flight exit.")
    data = ABI.encode("startIFEBondSize()", [])
    {:ok, result} = Ethereumex.HttpClient.eth_call(%{to: exit_game_contract_address, data: Encoding.to_hex(data)})

    result
    |> Encoding.to_binary()
    |> ABI.TypeDecoder.decode([{:uint, 128}])
    |> hd()
  end

  defp get_piggyback_bond_size(exit_game_contract_address) do
    _ = Logger.info("Trying to get bond size for piggback.")
    data = ABI.encode("piggybackBondSize()", [])
    {:ok, result} = Ethereumex.HttpClient.eth_call(%{to: exit_game_contract_address, data: Encoding.to_hex(data)})

    piggyback_bond_size =
      result
      |> Encoding.to_binary()
      |> ABI.TypeDecoder.decode([{:uint, 128}])
      |> hd()

    piggyback_bond_size
  end

  defp piggyback_output(exit_game_contract_address, piggyback_bond_size, address, output_index, exit_data) do
    _ = Logger.info("Piggyback output...")

    in_flight_tx = Encoding.to_binary(exit_data.in_flight_tx)

    data =
      ABI.encode(
        "piggybackInFlightExitOnOutput((bytes,uint16))",
        [{in_flight_tx, output_index}]
      )

    txmap = %{
      from: address,
      to: exit_game_contract_address,
      value: Encoding.to_hex(piggyback_bond_size),
      data: Encoding.to_hex(data),
      gas: Encoding.to_hex(@gas_piggyback)
    }

    {:ok, receipt_hash} = Ethereumex.HttpClient.eth_send_transaction(txmap)
    wait_on_receipt_confirmed(receipt_hash)
    _ = Logger.info("Piggyback output... DONE.")
    receipt_hash
  end

  defp piggyback_input(exit_game_contract_address, piggyback_bond_size, address, input_index, exit_data) do
    _ = Logger.info("Piggyback input...")

    in_flight_tx = Encoding.to_binary(exit_data.in_flight_tx)

    data =
      ABI.encode(
        "piggybackInFlightExitOnInput((bytes,uint16))",
        [{in_flight_tx, input_index}]
      )

    txmap = %{
      from: address,
      to: exit_game_contract_address,
      value: Encoding.to_hex(piggyback_bond_size),
      data: Encoding.to_hex(data),
      gas: Encoding.to_hex(@gas_piggyback)
    }

    {:ok, receipt_hash} = Ethereumex.HttpClient.eth_send_transaction(txmap)
    wait_on_receipt_confirmed(receipt_hash)
    _ = Logger.info("Piggyback input... DONE.")
    receipt_hash
  end

  defp add_exit_queue(address) do
    if has_exit_queue?() do
      _ = Logger.info("Exit queue was already added.")
      nil
    else
      _ = Logger.info("Exit queue missing. Adding...")

      data =
        ABI.encode(
          "addExitQueue(uint256,address)",
          [Itest.Account.vault_id(Currency.ether()), Currency.ether()]
        )

      txmap = %{
        from: address,
        to: Itest.Account.plasma_framework(),
        value: Encoding.to_hex(0),
        data: Encoding.to_hex(data),
        gas: Encoding.to_hex(@gas_add_exit_queue)
      }

      {:ok, receipt_hash} = Ethereumex.HttpClient.eth_send_transaction(txmap)
      wait_on_receipt_confirmed(receipt_hash)
      receipt_hash
    end
  end

  defp has_exit_queue?() do
    data =
      ABI.encode(
        "hasExitQueue(uint256,address)",
        [Itest.Account.vault_id(Currency.ether()), Currency.ether()]
      )

    {:ok, receipt_enc} =
      Ethereumex.HttpClient.eth_call(%{to: Itest.Account.plasma_framework(), data: Encoding.to_hex(data)})

    receipt_enc
    |> Encoding.to_binary()
    |> ABI.TypeDecoder.decode([:bool])
    |> hd()
>>>>>>> feature: introduce cabbage
  end
end

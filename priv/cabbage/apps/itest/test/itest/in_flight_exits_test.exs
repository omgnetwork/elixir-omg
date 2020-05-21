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

defmodule InFlightExitsTests do
  use Cabbage.Feature, async: false, file: "in_flight_exits.feature"

  require Logger

  alias ExPlasma.Transaction.Payment
  alias Itest.Account
  alias Itest.ApiModel.IfeCompetitor
  alias Itest.ApiModel.IfeExitData
  alias Itest.ApiModel.IfeExits
  alias Itest.ApiModel.IfeInputChallenge
  alias Itest.ApiModel.IfeOutputChallenge
  alias Itest.ApiModel.SubmitTransactionResponse
  alias Itest.ApiModel.Utxo
  alias Itest.ApiModel.WatcherSecurityCriticalConfiguration
  alias Itest.Client
  alias Itest.Fee
  alias Itest.StandardExitChallengeClient
  alias Itest.StandardExitClient
  alias Itest.Transactions.Currency
  alias Itest.Transactions.Encoding
  alias WatcherSecurityCriticalAPI.Api.InFlightExit
  alias WatcherSecurityCriticalAPI.Api.InFlightExit
  alias WatcherSecurityCriticalAPI.Api.Transaction
  alias WatcherSecurityCriticalAPI.Connection, as: Watcher
  alias WatcherSecurityCriticalAPI.Model.InFlightExitInputChallengeDataBodySchema
  alias WatcherSecurityCriticalAPI.Model.InFlightExitOutputChallengeDataBodySchema
  alias WatcherSecurityCriticalAPI.Model.InFlightExitTxBytesBodySchema
  alias WatcherSecurityCriticalAPI.Model.TransactionSubmitBodySchema

  use Bitwise

  import Itest.Poller,
    only: [
      pull_for_utxo_until_recognized_deposit: 4,
      pull_balance_until_amount: 2,
      pull_api_until_successful: 4,
      wait_on_receipt_confirmed: 1,
      all_events_in_status?: 1
    ]

  @ife_gas 2_000_000
  @ife_gas_price 1_000_000_000
  @gas_piggyback 1_000_000

  @gas_challenge_in_flight_exit_not_canonical 1_000_000
  @gas_process_exit 5_712_388
  @gas_process_exit_price 1_000_000_000

  setup do
    # as we're testing IFEs, queue needs to be empty
    0 = get_next_exit_from_queue()
    vault_address = Currency.ether() |> Itest.PlasmaFramework.vault() |> Encoding.to_hex()

    {:ok, _} =
      Itest.ContractEvent.start_link(
        ws_url: "ws://127.0.0.1:8546",
        name: :eth_vault,
        listen_to: %{"address" => vault_address},
        abi_path: Path.join([File.cwd!(), "../../../../data/plasma-contracts/contracts/", "EthVault.json"]),
        subscribe: self()
      )

    eth_fee =
      Currency.ether()
      |> Encoding.to_hex()
      |> Fee.get_for_currency()
      |> Map.get("amount")

    [{alice_address, alice_pkey}, {bob_address, bob_pkey}] = Account.take_accounts(2)

    exit_game_contract_address = Itest.PlasmaFramework.exit_game_contract_address(ExPlasma.payment_v1())

    %{
      "exit_game_contract_address" => exit_game_contract_address,
      "in_flight_exit_bond_size" => get_in_flight_exit_bond_size(exit_game_contract_address),
      "fee" => eth_fee,
      "Alice" => %{
        address: alice_address,
        pkey: "0x" <> alice_pkey,
        gas: 0,
        ethereum_balance: 0,
        ethereum_initial_balance: 0,
        child_chain_balance: 0,
        utxos: [],
        exit_data: nil,
        transaction_submit: nil,
        receipt_hashes: [],
        in_flight_exit_id: nil,
        in_flight_exit: nil
      },
      "Bob" => %{
        address: bob_address,
        pkey: "0x" <> bob_pkey,
        gas: 0,
        ethereum_balance: 0,
        ethereum_initial_balance: 0,
        child_chain_balance: 0,
        utxos: [],
        exit_data: nil,
        transaction_submit: nil,
        receipt_hashes: [],
        in_flight_exit_id: nil,
        in_flight_exit: nil
      }
    }
  end

  defgiven ~r/^"(?<entity>[^"]+)" deposits "(?<amount>[^"]+)" ETH to the root chain$/,
           %{entity: entity, amount: amount},
           state do
    Itest.Poller.get_balance(state[entity]) |> IO.inspect(label: "#{entity} deposits #{amount} ETH to the root chain")
    %{address: address} = entity_state = state[entity]
    initial_balance = Itest.Poller.root_chain_get_balance(address)

    {:ok, receipt_hash} =
      amount
      |> Currency.to_wei()
      |> Client.deposit(address, Itest.PlasmaFramework.vault(Currency.ether()))

    geth_block_every = 1

    {:ok, response} =
      WatcherSecurityCriticalAPI.Api.Configuration.configuration_get(WatcherSecurityCriticalAPI.Connection.new())

    watcher_security_critical_config =
      WatcherSecurityCriticalConfiguration.to_struct(Jason.decode!(response.body)["data"])

    finality_margin_blocks = watcher_security_critical_config.deposit_finality_margin
    to_miliseconds = 1000

    finality_margin_blocks
    |> Kernel.*(geth_block_every)
    |> Kernel.*(to_miliseconds)
    |> Kernel.round()
    |> Process.sleep()

    balance_after_deposit = Itest.Poller.root_chain_get_balance(address)
    deposited_amount = initial_balance - balance_after_deposit

    entity_state =
      entity_state
      |> Map.put(:ethereum_balance, balance_after_deposit)
      |> Map.put(:ethereum_initial_balance, initial_balance)
      |> Map.put(:last_deposited_amount, deposited_amount)
      |> Map.put(:receipt_hashes, [receipt_hash | entity_state.receipt_hashes])

    {:ok, Map.put(state, entity, entity_state)}
  end

  defthen ~r/^"(?<entity>[^"]+)" should have "(?<amount>[^"]+)" ETH on the child chain after finality margin$/,
          %{entity: entity, amount: amount},
          state do
    Itest.Poller.get_balance(state[entity]) |> IO.inspect(label: "#{entity} should have #{amount} ETH on the child chain after finality margin")
    %{address: address} = entity_state = state[entity]
    _ = Logger.info("#{entity} should have #{amount} ETH on the child chain after finality margin")

    child_chain_balance =
      case amount do
        "0" ->
          assert Client.get_exact_balance(address, Currency.to_wei(amount)) == []
          0

        _ ->
          %{"amount" => network_amount} = Client.get_exact_balance(address, Currency.to_wei(amount))
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

    balance = Itest.Poller.root_chain_get_balance(address)

    entity_state =
      entity_state
      |> Map.put(:ethereum_balance, balance)
      |> Map.put(:utxos, all_utxos["data"])
      |> Map.put(:child_chain_balance, child_chain_balance)

    {:ok, Map.put(state, entity, entity_state)}
  end

  # alice creates a transaction sending 5 eth to bob (creates! not sends!)
  # submitted_tx =
  #   OMG.TestHelper.create_signed(
  #     [{alice_deposit_blknum, txindex, oindex, alice}, {bob_deposit_blknum, txindex, oindex, bob}],
  #     @eth,
  #     [{alice, 5}, {bob, 15}]
  #   )
  # Note that alice output will not be 5, but 5 - tx fees
  defgiven ~r/^Alice and Bob create a transaction for "(?<amount>[^"]+)" ETH$/,
           %{amount: amount},
           state do
    amount = Currency.to_wei(amount)

    %{address: alice_address, utxos: alice_utxos, pkey: alice_pkey, child_chain_balance: alice_child_chain_balance} =
      alice_state = state["Alice"]

    %{address: bob_address, utxos: bob_utxos, pkey: bob_pkey, child_chain_balance: bob_child_chain_balance} =
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

    alice_output = %ExPlasma.Utxo{
      currency: Currency.ether(),
      owner: alice_address,
      amount: alice_child_chain_balance - Currency.to_wei(5) - state["fee"]
    }

    bob_output = %ExPlasma.Utxo{
      currency: Currency.ether(),
      owner: bob_address,
      amount: amount + bob_child_chain_balance
    }

    # NOTE: Bob-the-double-spender's input comes first, otherwise the currently used contracts impl has problems
    transaction = %Payment{inputs: [bob_deposit_input, alice_deposit_input], outputs: [alice_output, bob_output]}

    submitted_tx =
      ExPlasma.Transaction.sign(transaction,
        keys: [bob_pkey, alice_pkey]
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

  defgiven ~r/^Alice creates a transaction for "(?<amount>[^"]+)" ETH$/,
           %{amount: amount},
           state do
    Itest.Poller.get_balance(state["Alice"]) |> IO.inspect(label: "Alice creates a transaction for #{amount} ETH")
    amount = Currency.to_wei(amount)

    %{address: alice_address, utxos: alice_utxos, pkey: alice_pkey, child_chain_balance: alice_child_chain_balance} =
      alice_state = state["Alice"]

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

    alice_output_1 = %ExPlasma.Utxo{
      currency: Currency.ether(),
      owner: alice_address,
      amount: amount
    }

    rest = alice_child_chain_balance - amount - state["fee"]

    alice_output_2 = %ExPlasma.Utxo{
      currency: Currency.ether(),
      owner: alice_address,
      amount: rest
    }

    transaction = %Payment{inputs: [alice_deposit_input], outputs: [alice_output_1, alice_output_2]}

    in_flight_tx =
      ExPlasma.Transaction.sign(transaction,
        keys: [alice_pkey]
      )

    txbytes = ExPlasma.Transaction.encode(in_flight_tx)
    alice_state = Map.put(alice_state, :txbytes, txbytes)

    entity = "Alice"
    {:ok, Map.put(state, entity, alice_state)}
  end

  defand ~r/^Bob gets in flight exit data for "(?<amount>[^"]+)" ETH from his most recent deposit$/,
         %{amount: amount},
         state do
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

    unsigned_submitted_tx =
      ExPlasma.Transaction.sign(transaction,
        keys: []
      )

    unsigned_txbytes = ExPlasma.Transaction.encode(unsigned_submitted_tx)

    payload = %InFlightExitTxBytesBodySchema{txbytes: Encoding.to_hex(txbytes)}
    response = pull_api_until_successful(InFlightExit, :in_flight_exit_get_data, Watcher.new(), payload)
    exit_data = IfeExitData.to_struct(response)

    bob_state =
      bob_state
      |> Map.put(:exit_data, exit_data)
      |> Map.put(:unsigned_txbytes, unsigned_txbytes)

    entity = "Bob"
    {:ok, Map.put(state, entity, bob_state)}
  end

  defand ~r/^Alice sends the most recently created transaction$/, _, state do
    Itest.Poller.get_balance(state["Alice"]) |> IO.inspect(label: "Alice sends the most recently created transaction")
    %{txbytes: txbytes} = alice_state = state["Alice"]

    submit_transaction_response = send_transaction(txbytes)

    alice_state = Map.put(alice_state, :transaction_submit, submit_transaction_response)

    entity = "Alice"
    {:ok, Map.put(state, entity, alice_state)}
  end

  defand ~r/^Bob spends an output from the most recently sent transaction$/, _, state do
    %{address: alice_address, transaction_submit: alice_transaction_submit} = state["Alice"]

    %{address: bob_address, pkey: bob_pkey} = bob_state = state["Bob"]
    # Bob sends a transaction spending Alices outputs
    # inputs
    bob_input = %ExPlasma.Utxo{
      blknum: alice_transaction_submit.blknum,
      currency: Currency.ether(),
      oindex: 1,
      txindex: alice_transaction_submit.txindex,
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

    bob_output = %ExPlasma.Utxo{
      currency: Currency.ether(),
      owner: bob_address,
      amount: Currency.to_wei(10) - state["fee"]
    }

    transaction = %Payment{inputs: [bob_input], outputs: [alice_output1, alice_output2, bob_output]}

    submitted_tx =
      ExPlasma.Transaction.sign(transaction,
        keys: [bob_pkey]
      )

    txbytes = ExPlasma.Transaction.encode(submitted_tx)

    submit_transaction_response = send_transaction(txbytes)

    bob_state =
      bob_state
      |> Map.put(:submitted_tx, submitted_tx)
      |> Map.put(:txbytes, txbytes)
      |> Map.put(:transaction_submit, submit_transaction_response)

    entity = "Bob"
    {:ok, Map.put(state, entity, bob_state)}
  end

  defand ~r/^Alice starts an in flight exit from the most recently created transaction$/, _, state do
    Itest.Poller.get_balance(state["Alice"]) |> IO.inspect(label: "Alice starts an in flight exit from the most recently created transaction")

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

  defgiven ~r/^"(?<entity>[^"]+)" verifies its in flight exit from the most recently created transaction$/,
           %{entity: entity},
           state do
    Itest.Poller.get_balance(state[entity]) |> IO.inspect(label: "#{entity} verifies its in flight exit from the most recently created transaction")
    exit_game_contract_address = state["exit_game_contract_address"]
    %{exit_data: exit_data} = entity_state = state[entity]

    in_flight_exit_id = get_in_flight_exit_id(exit_game_contract_address, exit_data)
    [in_flight_exit] = get_in_flight_exits(exit_game_contract_address, in_flight_exit_id)
    assert in_flight_exit.exit_map == 0

    entity_state =
      entity_state
      |> Map.put(:in_flight_exit_id, in_flight_exit_id)
      |> Map.put(:in_flight_exit, in_flight_exit)

    {:ok, Map.put(state, entity, entity_state)}
  end

  defgiven ~r/^Bob piggybacks inputs and outputs from Alices most recent in flight exit$/, _, state do
    exit_game_contract_address = state["exit_game_contract_address"]

    %{exit_data: exit_data, in_flight_exit_id: in_flight_exit_id} = state["Alice"]
    %{address: address} = bob_state = state["Bob"]

    output_index = 1
    input_index = 0

    receipt_hash_1 = piggyback_output(exit_game_contract_address, address, output_index, exit_data)
    receipt_hash_2 = piggyback_input(exit_game_contract_address, address, input_index, exit_data)

    bob_state =
      Map.put(
        bob_state,
        :receipt_hashes,
        Enum.concat([receipt_hash_1, receipt_hash_2], bob_state.receipt_hashes)
      )

    [in_flight_exit] = get_in_flight_exits(exit_game_contract_address, in_flight_exit_id)
    # bits is flagged when output is piggybacked
    assert in_flight_exit.exit_map != 0
    entity = "Bob"

    {:ok, Map.put(state, entity, bob_state)}
  end

  defgiven ~r/^Alice piggybacks output from her most recent in flight exit$/, _, state do
    Itest.Poller.get_balance(state["Alice"]) |> IO.inspect(label: "Alice piggybacks output from her most recent in flight exit")
    exit_game_contract_address = state["exit_game_contract_address"]

    %{address: address, exit_data: exit_data, in_flight_exit_id: in_flight_exit_id} = alice_state = state["Alice"]

    output_index = 0
    receipt_hash_1 = piggyback_output(exit_game_contract_address, address, output_index, exit_data)

    alice_state =
      Map.put(
        alice_state,
        :receipt_hashes,
        Enum.concat([receipt_hash_1], alice_state.receipt_hashes)
      )

    [in_flight_exit] = get_in_flight_exits(exit_game_contract_address, in_flight_exit_id)
    # bits is flagged when output is piggybacked
    assert in_flight_exit.exit_map != 0

    entity = "Alice"
    {:ok, Map.put(state, entity, alice_state)}
  end

  # ### start the competing IFE, to double-spend some inputs
  defand ~r/^Bob starts a piggybacked in flight exit using his most recently prepared in flight exit data$/, _, state do
    exit_game_contract_address = state["exit_game_contract_address"]
    in_flight_exit_bond_size = state["in_flight_exit_bond_size"]
    %{address: address, exit_data: exit_data} = bob_state = state["Bob"]

    output_index = 0
    input_index = 0

    receipt_hash = do_in_flight_exit(exit_game_contract_address, in_flight_exit_bond_size, address, exit_data)

    # only piggyback_available for tx2 is present, tx1 is included in block and does not spawn that event
    # excapt the awaited piggyback_available, invalid_piggyback and non_canonical_ife appear, b/c of the double-spend
    assert all_events_in_status?(["invalid_piggyback", "non_canonical_ife", "piggyback_available"])

    # NOTE: the reason to piggyback this IFE fully is to be able to leave the system in clean and secure state, without
    #       any remaining `piggyback_available` events
    receipt_hash_1 = piggyback_output(exit_game_contract_address, address, output_index, exit_data)
    receipt_hash_2 = piggyback_input(exit_game_contract_address, address, input_index, exit_data)

    bob_state =
      Map.put(
        bob_state,
        :receipt_hashes,
        Enum.concat([receipt_hash, receipt_hash_1, receipt_hash_2], bob_state.receipt_hashes)
      )

    entity = "Bob"

    {:ok, Map.put(state, entity, bob_state)}
  end

  defand ~r/^Alice fully challenges Bobs most recent invalid in flight exit$/, _, state do
    exit_game_contract_address = state["exit_game_contract_address"]

    %{
      address: address,
      in_flight_exit_id: in_flight_exit_id,
      in_flight_exit: in_flight_exit,
      unsigned_txbytes: unsigned_txbytes
    } = alice_state = state["Alice"]

    %{address: bob_address, unsigned_txbytes: bob_unsigned_txbytes} = state["Bob"]

    # only a single non_canonical event, since one of the IFE txs is included!
    # I’m waiting for these three, and only these three to appear
    # there's 2x invalid_piggyback, because the other IFE from Bob has an invalidly piggybacked input too
    # SLA margin passed so there are unchallenged exit events
    assert all_events_in_status?([
             "unchallenged_non_canonical_ife",
             "unchallenged_piggyback",
             "unchallenged_piggyback",
             "invalid_piggyback",
             "invalid_piggyback",
             "non_canonical_ife"
           ])

    ###
    # CANONICITY GAME
    ###

    payload = %InFlightExitTxBytesBodySchema{txbytes: Encoding.to_hex(bob_unsigned_txbytes)}

    response = pull_api_until_successful(InFlightExit, :in_flight_exit_get_competitor, Watcher.new(), payload)
    ife_competitor = IfeCompetitor.to_struct(response)

    assert ife_competitor.competing_tx_pos > 0
    assert ife_competitor.competing_proof != ""
    challenge_in_flight_exit_not_canonical(exit_game_contract_address, bob_address, ife_competitor)

    # I’m waiting for only these two to remain
    # there's 2x invalid_piggyback, because the other IFE from Bob has an invalidly piggybacked input too
    # SLA margin passed so there are unchallenged exit events
    assert all_events_in_status?([
             "unchallenged_piggyback",
             "unchallenged_piggyback",
             "invalid_piggyback",
             "invalid_piggyback"
           ])

    ###
    # PIGGYBACKS
    ###

    # First input challenge
    payload_0 = %InFlightExitInputChallengeDataBodySchema{txbytes: Encoding.to_hex(unsigned_txbytes), input_index: 0}

    response_0 =
      pull_api_until_successful(InFlightExit, :in_flight_exit_get_input_challenge_data, Watcher.new(), payload_0)

    ife_input_challenge_0 = IfeInputChallenge.to_struct(response_0)
    assert ife_input_challenge_0.in_flight_txbytes == Encoding.to_hex(unsigned_txbytes)
    receipt_hash_0 = challenge_in_flight_exit_input_spent(exit_game_contract_address, address, ife_input_challenge_0)
    # sanity check
    [in_flight_exit_0] = get_in_flight_exits(exit_game_contract_address, in_flight_exit_id)
    assert in_flight_exit_0.exit_map != in_flight_exit.exit_map
    assert in_flight_exit_0.exit_map != 0

    # Second input challenge
    payload_1 = %InFlightExitInputChallengeDataBodySchema{
      txbytes: Encoding.to_hex(bob_unsigned_txbytes),
      input_index: 0
    }

    response_1 =
      pull_api_until_successful(InFlightExit, :in_flight_exit_get_input_challenge_data, Watcher.new(), payload_1)

    ife_input_challenge_1 = IfeInputChallenge.to_struct(response_1)
    assert ife_input_challenge_1.in_flight_txbytes == Encoding.to_hex(bob_unsigned_txbytes)
    receipt_hash_1 = challenge_in_flight_exit_input_spent(exit_game_contract_address, address, ife_input_challenge_1)
    # sanity check
    # leaving this with no sanity check here, to limit complexity

    # output challenge
    payload_2 = %InFlightExitOutputChallengeDataBodySchema{txbytes: Encoding.to_hex(unsigned_txbytes), output_index: 1}

    response_2 =
      pull_api_until_successful(InFlightExit, :in_flight_exit_get_output_challenge_data, Watcher.new(), payload_2)

    ife_output_challenge_2 = IfeOutputChallenge.to_struct(response_2)
    assert ife_output_challenge_2.in_flight_txbytes == Encoding.to_hex(unsigned_txbytes)
    receipt_hash_2 = challenge_in_flight_exit_output_spent(exit_game_contract_address, address, ife_output_challenge_2)
    # observe the result - piggybacks are gone
    [in_flight_exit_2] = get_in_flight_exits(exit_game_contract_address, in_flight_exit_id)
    assert in_flight_exit_2.exit_map == 0

    # observe the byzantine events gone
    # I’m waiting for clean state / secure chain to remain after all the challenges
    assert all_events_in_status?([])

    alice_state =
      Map.put(
        alice_state,
        :receipt_hashes,
        Enum.concat([receipt_hash_0, receipt_hash_1, receipt_hash_2], alice_state.receipt_hashes)
      )

    entity = "Alice"
    {:ok, Map.put(state, entity, alice_state)}
  end

  defthen ~r/^"(?<entity>[^"]+)" can processes its own most recent in flight exit$/, %{entity: entity}, state do
    %{address: address} = entity_state = state[entity]
    _ = wait_for_min_exit_period()

    receipt_hash = process_exits(address)

    assert get_next_exit_from_queue() == 0

    entity_state = Map.put(entity_state, :receipt_hashes, [receipt_hash | entity_state.receipt_hashes])
    {:ok, Map.put(state, entity, entity_state)}
  end

  defwhen ~r/^Bob sends Alice "(?<amount>[^"]+)" ETH on the child chain$/,
          %{amount: amount},
          state do
    amount = Currency.to_wei(amount)

    %{address: alice_address} = state["Alice"]

    %{address: bob_address, utxos: bob_utxos, pkey: bob_pkey, child_chain_balance: bob_child_chain_balance} =
      state["Bob"]

    # inputs
    bob_deposit_utxo = hd(bob_utxos)

    bob_input = %ExPlasma.Utxo{
      blknum: bob_deposit_utxo["blknum"],
      currency: Currency.ether(),
      oindex: 0,
      txindex: 0,
      output_type: 1,
      owner: bob_address
    }

    alice_output = %ExPlasma.Utxo{
      currency: Currency.ether(),
      owner: alice_address,
      amount: amount
    }

    bob_output = %ExPlasma.Utxo{
      currency: Currency.ether(),
      owner: bob_address,
      amount: bob_child_chain_balance - amount - state["fee"]
    }

    transaction = %Payment{inputs: [bob_input], outputs: [alice_output, bob_output]}

    submitted_tx =
      ExPlasma.Transaction.sign(transaction,
        keys: [bob_pkey]
      )

    txbytes = ExPlasma.Transaction.encode(submitted_tx)

    _submit_transaction_response = send_transaction(txbytes)

    {:ok, state}
  end

  defthen ~r/^"(?<entity>[^"]+)" should have "(?<amount>[^"]+)" ETH on the child chain after a successful transaction$/,
          %{entity: entity, amount: amount},
          state do
    %{address: address} = entity_state = state[entity]
    _ = Logger.info("#{entity} should have #{amount} ETH on the child chain after a successful transaction")

    amount = Currency.to_wei(amount)
    %{"amount" => child_chain_balance} = pull_balance_until_amount(address, amount)

    {:ok, %{"data" => all_utxos}} = Client.get_utxos(%{address: address})

    entity_state =
      entity_state
      |> Map.put(:utxos, all_utxos)
      |> Map.put(:child_chain_balance, child_chain_balance)

    {:ok, Map.put(state, entity, entity_state)}
  end

  # Alice creates a transaction sending 5 eth to bob (creates! not sends!)
  defgiven ~r/^Alice creates a transaction spending her recently received input to Bob$/,
           _,
           state do
    %{utxos: alice_utxos, pkey: alice_pkey} = alice_state = state["Alice"]

    amount = Currency.to_wei(5)

    %{address: bob_address} = state["Bob"]

    double_spent_utxo = alice_utxos |> Enum.reverse() |> Enum.at(0)

    assert double_spent_utxo["amount"] == amount

    alice_deposit_input = %ExPlasma.Utxo{
      blknum: double_spent_utxo["blknum"],
      currency: double_spent_utxo["currency"],
      oindex: double_spent_utxo["oindex"],
      txindex: double_spent_utxo["txindex"],
      output_type: double_spent_utxo["otype"],
      owner: double_spent_utxo["owner"]
    }

    bob_output = %ExPlasma.Utxo{
      currency: Currency.ether(),
      owner: bob_address,
      amount: amount - state["fee"]
    }

    transaction = %Payment{inputs: [alice_deposit_input], outputs: [bob_output]}

    submitted_tx =
      ExPlasma.Transaction.sign(transaction,
        keys: [alice_pkey]
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

  defwhen ~r/^Alice starts a standard exit on the child chain from her recently received input from Bob$/,
          _,
          state do
    %{utxos: alice_utxos, address: alice_address} = state["Alice"]
    utxo = alice_utxos |> Enum.reverse() |> Enum.at(0)

    assert utxo["amount"] == Currency.to_wei(5)

    standard_exit_client = %StandardExitClient{address: alice_address, utxo: Utxo.to_struct(utxo)}
    StandardExitClient.start_standard_exit(standard_exit_client)

    {:ok, state}
  end

  defand ~r/^Bob starts an in flight exit from the most recently created transaction$/, _, state do
    exit_game_contract_address = state["exit_game_contract_address"]
    in_flight_exit_bond_size = state["in_flight_exit_bond_size"]
    %{txbytes: txbytes} = state["Alice"]
    %{address: bob_address} = bob_state = state["Bob"]
    payload = %InFlightExitTxBytesBodySchema{txbytes: Encoding.to_hex(txbytes)}
    response = pull_api_until_successful(InFlightExit, :in_flight_exit_get_data, Watcher.new(), payload)
    exit_data = IfeExitData.to_struct(response)
    receipt_hash = do_in_flight_exit(exit_game_contract_address, in_flight_exit_bond_size, bob_address, exit_data)

    bob_state =
      bob_state
      |> Map.put(:exit_data, exit_data)
      |> Map.put(:receipt_hashes, [receipt_hash | bob_state.receipt_hashes])

    entity = "Bob"
    {:ok, Map.put(state, entity, bob_state)}
  end

  defgiven ~r/^Bob piggybacks outputs from his most recent in flight exit$/, _, state do
    exit_game_contract_address = state["exit_game_contract_address"]

    %{exit_data: exit_data, in_flight_exit_id: in_flight_exit_id, address: address} = bob_state = state["Bob"]

    output_index = 0

    receipt_hash_1 = piggyback_output(exit_game_contract_address, address, output_index, exit_data)

    bob_state =
      Map.put(
        bob_state,
        :receipt_hashes,
        Enum.concat([receipt_hash_1], bob_state.receipt_hashes)
      )

    [in_flight_exit] = get_in_flight_exits(exit_game_contract_address, in_flight_exit_id)
    # bits is flagged when output is piggybacked
    assert in_flight_exit.exit_map != 0
    entity = "Bob"

    {:ok, Map.put(state, entity, bob_state)}
  end

  defwhen ~r/^Bob fully challenges Alices most recent invalid exit$/,
          _,
          state do
    assert all_events_in_status?(["invalid_exit"])

    %{exit_data: %{input_utxos_pos: [utxo_pos | _]}, address: address} = state["Bob"]

    StandardExitChallengeClient.challenge_standard_exit(utxo_pos, address)

    {:ok, state}
  end

  defwhen ~r/^Alice piggybacks inputs from Bobs most recent in flight exit$/, _, state do
    Itest.Poller.get_balance(state["Alice"]) |> IO.inspect(label: "Alice piggybacks inputs from Bobs most recent in flight exit")
    exit_game_contract_address = state["exit_game_contract_address"]

    %{exit_data: exit_data, in_flight_exit_id: in_flight_exit_id} = state["Bob"]
    %{address: address} = alice_state = state["Alice"]

    input_index = 0

    receipt_hash_1 = piggyback_input(exit_game_contract_address, address, input_index, exit_data)

    alice_state =
      Map.put(
        alice_state,
        :receipt_hashes,
        Enum.concat([receipt_hash_1], alice_state.receipt_hashes)
      )

    [in_flight_exit] = get_in_flight_exits(exit_game_contract_address, in_flight_exit_id)
    # bits is flagged when input is piggybacked
    assert in_flight_exit.exit_map != 0
    entity = "Alice"

    {:ok, Map.put(state, entity, alice_state)}
  end

  # And "Alice" in flight transaction inputs are not spendable after exit finalization
  defand ~r/^"(?<entity>[^"]+)" in flight transaction inputs are not spendable any more$/,
         %{entity: entity},
         state do
    %{address: address, in_flight_exit: in_flight_exit} = state[entity]

    assert Itest.Poller.utxo_absent?(address, in_flight_exit.position)
    assert Itest.Poller.exitable_utxo_absent?(address, in_flight_exit.position)

    {:ok, state}
  end

  defand ~r/^"(?<entity>[^"]+)" in flight transaction most recently piggybacked output is not spendable any more$/,
         %{entity: entity},
         state do
    Itest.Poller.get_balance(state[entity]) |> IO.inspect(label: "#{entity} in flight transaction most recently piggybacked output is not spendable any more")

    %{address: address, transaction_submit: submit_response, child_chain_balance: balance} = state[entity]
    piggybacked_output_index = 0
    %SubmitTransactionResponse{blknum: output_blknum, txindex: output_txindex} = submit_response

    pull_balance_until_amount(address, balance - Currency.to_wei(5))

    {:ok, %{"data" => utxos}} = Client.get_utxos(%{address: address})

    assert nil ==
             Enum.find(
               utxos,
               fn %{"blknum" => blknum, "txindex" => txindex, "oindex" => oindex} ->
                 blknum == output_blknum and txindex == output_txindex and oindex == piggybacked_output_index
               end
             )
  end

  ###############################################################################################
  ####
  #### PRIVATE
  ####
  ###############################################################################################

  defp send_transaction(txbytes) do
    transaction_submit_body_schema = %TransactionSubmitBodySchema{transaction: Encoding.to_hex(txbytes)}
    {:ok, response} = Transaction.submit(Watcher.new(), transaction_submit_body_schema)

    try do
      response
      |> Map.get(:body)
      |> Jason.decode!()
      |> Map.get("data")
      |> SubmitTransactionResponse.to_struct()
    rescue
      _x in [MatchError] ->
        _ = Process.sleep(5_000)
        send_transaction(txbytes)
    end
  end

  defp process_exits(address) do
    _ = Logger.info("Process exits #{__MODULE__}")

    # 2 means we're processing up to 2 exits, since this test starts exactly 2 exits now
    # we can't make precise claims on which exit is at the top, since this might change depending on the setup
    # the important part is that there is an assertion that those exits got processed
    data =
      ABI.encode(
        "processExits(uint256,address,uint160,uint256)",
        [Itest.PlasmaFramework.vault_id(Currency.ether()), Currency.ether(), 0, 2]
      )

    txmap = %{
      from: address,
      to: Itest.PlasmaFramework.address(),
      value: Encoding.to_hex(0),
      data: Encoding.to_hex(data),
      gas: Encoding.to_hex(@gas_process_exit),
      gasPrice: Encoding.to_hex(@gas_process_exit_price)
    }

    {:ok, receipt_hash} = Ethereumex.HttpClient.eth_send_transaction(txmap)
    wait_on_receipt_confirmed(receipt_hash)

    receipt_hash
  end

  defp get_next_exit_from_queue() do
    data =
      ABI.encode("getNextExit(uint256,address)", [Itest.PlasmaFramework.vault_id(Currency.ether()), Currency.ether()])

    {:ok, result} = Ethereumex.HttpClient.eth_call(%{to: Itest.PlasmaFramework.address(), data: Encoding.to_hex(data)})

    case Encoding.to_binary(result) do
      "" ->
        :queue_not_added

      result ->
        next_exit_id = hd(ABI.TypeDecoder.decode(result, [{:uint, 256}]))
        next_exit_id &&& (1 <<< 160) - 1
    end
  end

  defp wait_for_min_exit_period() do
    _ = Logger.info("Wait for exit period to pass.")
    data = ABI.encode("minExitPeriod()", [])
    {:ok, result} = Ethereumex.HttpClient.eth_call(%{to: Itest.PlasmaFramework.address(), data: Encoding.to_hex(data)})
    # result is in seconds
    result
    |> Encoding.to_binary()
    |> ABI.TypeDecoder.decode([{:uint, 160}])
    |> hd()
    # to milliseconds
    |> Kernel.*(1000)
    # needs a be a tiny more than exit period seconds
    |> Kernel.+(1000)
    # twice the amount of min exit period for for a freshly submitted utxo IFE
    |> Kernel.*(2)
    |> Process.sleep()
  end

  defp challenge_in_flight_exit_not_canonical(exit_game_contract_address, address, ife_competitor) do
    values = [
      {Encoding.to_binary(ife_competitor.input_tx), ife_competitor.input_utxo_pos,
       Encoding.to_binary(ife_competitor.in_flight_txbytes), ife_competitor.in_flight_input_index,
       Encoding.to_binary(ife_competitor.competing_txbytes), ife_competitor.competing_input_index,
       ife_competitor.competing_tx_pos, Encoding.to_binary(ife_competitor.competing_proof),
       Encoding.to_binary(ife_competitor.competing_sig)}
    ]

    data =
      ABI.encode(
        "challengeInFlightExitNotCanonical((bytes,uint256,bytes,uint16,bytes,uint16,uint256,bytes,bytes))",
        values
      )

    txmap = %{
      from: address,
      to: exit_game_contract_address,
      value: Encoding.to_hex(0),
      data: Encoding.to_hex(data),
      gas: Encoding.to_hex(@gas_challenge_in_flight_exit_not_canonical),
      gasPrice: Encoding.to_hex(@ife_gas_price)
    }

    {:ok, receipt_hash} = Ethereumex.HttpClient.eth_send_transaction(txmap)
    wait_on_receipt_confirmed(receipt_hash)

    receipt_hash
  end

  defp challenge_in_flight_exit_input_spent(
         exit_game_contract_address,
         "0x" <> rest_address = address,
         ife_input_challenge
       ) do
    values = [
      {Encoding.to_binary(ife_input_challenge.in_flight_txbytes), ife_input_challenge.in_flight_input_index,
       Encoding.to_binary(ife_input_challenge.spending_txbytes), ife_input_challenge.spending_input_index,
       Encoding.to_binary(ife_input_challenge.spending_sig), Encoding.to_binary(ife_input_challenge.input_tx),
       ife_input_challenge.input_utxo_pos, rest_address |> Base.decode16!(case: :lower) |> :keccakf1600.sha3_256()}
    ]

    data =
      ABI.encode(
        "challengeInFlightExitInputSpent((bytes,uint16,bytes,uint16,bytes,bytes,uint256,bytes32))",
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
    _ = Logger.info("Done challenge IFE input #{receipt_hash}")
    wait_on_receipt_confirmed(receipt_hash)

    receipt_hash
  end

  defp challenge_in_flight_exit_output_spent(
         exit_game_contract_address,
         "0x" <> rest_address = address,
         ife_output_challenge
       ) do
    values = [
      {Encoding.to_binary(ife_output_challenge.in_flight_txbytes),
       Encoding.to_binary(ife_output_challenge.in_flight_proof), ife_output_challenge.in_flight_output_pos,
       Encoding.to_binary(ife_output_challenge.spending_txbytes), ife_output_challenge.spending_input_index,
       Encoding.to_binary(ife_output_challenge.spending_sig),
       rest_address |> Base.decode16!(case: :lower) |> :keccakf1600.sha3_256()}
    ]

    data =
      ABI.encode(
        "challengeInFlightExitOutputSpent((bytes,bytes,uint256,bytes,uint16,bytes,bytes32))",
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
    _ = Logger.info("Done challenge IFE output #{receipt_hash}")
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
    data = ABI.encode("inFlightExits(uint160[])", [[ife_exit_id]])
    {:ok, result} = Ethereumex.HttpClient.eth_call(%{to: exit_game_contract_address, data: Encoding.to_hex(data)})

    return_struct = [
      {:array,
       {
         :tuple,
         [
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
       }}
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

    # A temporary work around for `ex_abi` incorrectly decoding arrays.
    # See https://github.com/poanetwork/ex_abi/issues/22
    <<32::size(32)-unit(8), raw_array_data::binary>> = Encoding.to_binary(result)

    ife_exit_ids =
      raw_array_data
      |> ABI.TypeDecoder.decode(return_struct)
      |> Enum.map(&IfeExits.to_struct(&1, return_fields))

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

  defp get_in_flight_exit_bond_size(exit_game_contract_address) do
    _ = Logger.info("Trying to get bond size for in flight exit.")
    data = ABI.encode("startIFEBondSize()", [])
    {:ok, result} = Ethereumex.HttpClient.eth_call(%{to: exit_game_contract_address, data: Encoding.to_hex(data)})

    result
    |> Encoding.to_binary()
    |> ABI.TypeDecoder.decode([{:uint, 128}])
    |> hd()
  end

  defp piggyback_output(exit_game_contract_address, address, output_index, exit_data) do
    piggyback_bond_size = get_piggyback_bond_size(exit_game_contract_address)
    _ = Logger.info("Piggyback output...")

    data =
      ABI.encode(
        "piggybackInFlightExitOnOutput((bytes,uint16))",
        [{Encoding.to_binary(exit_data.in_flight_tx), output_index}]
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

  defp piggyback_input(exit_game_contract_address, address, input_index, exit_data) do
    piggyback_bond_size = get_piggyback_bond_size(exit_game_contract_address)
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
end

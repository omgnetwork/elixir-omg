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

defmodule OMG.WatcherInfo.DB.EthEventTest do
  use ExUnitFixtures
  use ExUnit.Case, async: false
  use OMG.Fixtures

  import Ecto.Query

  alias OMG.Crypto
  alias OMG.Utxo
  alias OMG.WatcherInfo.DB

  alias OMG.WatcherInfo.Factory

  require Utxo

  @eth OMG.Eth.RootChain.eth_pseudo_address()

  @tag fixtures: [:phoenix_ecto_sandbox]
  test "insert deposits: creates deposit event and utxo" do
    expected_root_chain_txnhash = Crypto.hash(<<1::256>>)
    expected_log_index = 0
    expected_event_type = :deposit

    expected_blknum = 10_000
    expected_txindex = 0
    expected_oindex = 0
    expected_owner = <<1::160>>
    expected_currency = @eth
    expected_amount = 1

    expected_child_chain_utxohash =
      DB.TxOutput.generate_child_chain_utxohash(Utxo.position(expected_blknum, expected_txindex, expected_oindex))

    assert :ok =
             DB.EthEvent.insert_deposits!([
               %{
                 root_chain_txhash: expected_root_chain_txnhash,
                 log_index: expected_log_index,
                 blknum: expected_blknum,
                 owner: expected_owner,
                 currency: expected_currency,
                 amount: expected_amount
               }
             ])

    event =
      DB.EthEvent.get_by_composite_pk(%{root_chain_txhash: expected_root_chain_txnhash, log_index: expected_log_index})

    assert %DB.EthEvent{
             root_chain_txhash: ^expected_root_chain_txnhash,
             log_index: ^expected_log_index,
             event_type: ^expected_event_type
           } = event

    # check ethevent side of relationship
    assert length(event.txoutputs) == 1

    assert [
             %DB.TxOutput{
               blknum: ^expected_blknum,
               txindex: ^expected_txindex,
               oindex: ^expected_oindex,
               owner: ^expected_owner,
               amount: ^expected_amount,
               currency: ^expected_currency,
               creating_txhash: nil,
               spending_txhash: nil,
               spending_tx_oindex: nil,
               proof: nil,
               child_chain_utxohash: ^expected_child_chain_utxohash
             }
             | _tail
           ] = event.txoutputs

    # check txoutput side of relationship
    txoutput = DB.TxOutput.get_by_position(Utxo.position(expected_blknum, expected_txindex, expected_oindex))

    assert %DB.TxOutput{
             blknum: ^expected_blknum,
             txindex: ^expected_txindex,
             oindex: ^expected_oindex,
             owner: ^expected_owner,
             amount: ^expected_amount,
             currency: ^expected_currency,
             creating_txhash: nil,
             spending_txhash: nil,
             spending_tx_oindex: nil,
             proof: nil,
             child_chain_utxohash: ^expected_child_chain_utxohash
           } = txoutput

    assert length(txoutput.ethevents) == 1

    assert [
             %DB.EthEvent{
               root_chain_txhash: ^expected_root_chain_txnhash,
               log_index: ^expected_log_index,
               event_type: ^expected_event_type
             }
             | _tail
           ] = txoutput.ethevents
  end

  @tag fixtures: [:phoenix_ecto_sandbox, :alice]
  test "insert deposits: creates deposits and retrieves them by hash", %{alice: alice} do
    expected_event_type = :deposit
    expected_owner = alice.addr
    expected_currency = @eth
    expected_log_index = 0
    expected_amount = 1

    expected_root_chain_txhash_1 = Crypto.hash(<<2::256>>)

    expected_root_chain_txhash_event_1 =
      DB.EthEvent.generate_root_chain_txhash_event(expected_root_chain_txhash_1, expected_log_index)

    expected_blknum_1 = 20_000

    expected_root_chain_txhash_2 = Crypto.hash(<<3::256>>)

    expected_root_chain_txhash_event_2 =
      DB.EthEvent.generate_root_chain_txhash_event(expected_root_chain_txhash_2, expected_log_index)

    expected_blknum_2 = 30_000

    expected_root_chain_txhash_3 = Crypto.hash(<<4::256>>)

    expected_root_chain_txhash_event_3 =
      DB.EthEvent.generate_root_chain_txhash_event(expected_root_chain_txhash_3, expected_log_index)

    expected_blknum_3 = 40_000

    assert :ok =
             DB.EthEvent.insert_deposits!([
               %{
                 root_chain_txhash: expected_root_chain_txhash_1,
                 log_index: expected_log_index,
                 blknum: expected_blknum_1,
                 owner: expected_owner,
                 currency: expected_currency,
                 amount: expected_amount
               },
               %{
                 root_chain_txhash: expected_root_chain_txhash_2,
                 log_index: expected_log_index,
                 blknum: expected_blknum_2,
                 owner: expected_owner,
                 currency: expected_currency,
                 amount: expected_amount
               },
               %{
                 root_chain_txhash: expected_root_chain_txhash_3,
                 log_index: expected_log_index,
                 blknum: expected_blknum_3,
                 owner: expected_owner,
                 currency: expected_currency,
                 amount: expected_amount
               }
             ])

    assert %DB.EthEvent{
             root_chain_txhash: ^expected_root_chain_txhash_1,
             log_index: ^expected_log_index,
             event_type: ^expected_event_type,
             root_chain_txhash_event: ^expected_root_chain_txhash_event_1
           } =
             DB.EthEvent.get_by_composite_pk(%{
               root_chain_txhash: expected_root_chain_txhash_1,
               log_index: expected_log_index
             })

    assert %DB.EthEvent{
             root_chain_txhash: ^expected_root_chain_txhash_2,
             log_index: ^expected_log_index,
             event_type: ^expected_event_type,
             root_chain_txhash_event: ^expected_root_chain_txhash_event_2
           } =
             DB.EthEvent.get_by_composite_pk(%{
               root_chain_txhash: expected_root_chain_txhash_2,
               log_index: expected_log_index
             })

    assert %DB.EthEvent{
             root_chain_txhash: ^expected_root_chain_txhash_3,
             log_index: ^expected_log_index,
             event_type: ^expected_event_type,
             root_chain_txhash_event: ^expected_root_chain_txhash_event_3
           } =
             DB.EthEvent.get_by_composite_pk(%{
               root_chain_txhash: expected_root_chain_txhash_3,
               log_index: expected_log_index
             })

    assert [^expected_root_chain_txhash_1, ^expected_root_chain_txhash_2, ^expected_root_chain_txhash_3] =
             DB.TxOutput.get_utxos(alice.addr)
             |> Enum.map(fn txoutput ->
               [head | _tail] = txoutput.ethevents
               head.root_chain_txhash
             end)
  end

  @tag fixtures: [:alice, :initial_blocks]
  test "Writes of deposits and exits are idempotent", %{alice: alice} do
    # try to insert again existing deposit (from initial_blocks)
    assert :ok =
             DB.EthEvent.insert_deposits!([
               %{
                 root_chain_txhash: Crypto.hash(<<1000::256>>),
                 log_index: 0,
                 owner: alice.addr,
                 currency: @eth,
                 amount: 333,
                 blknum: 1
               }
             ])

    exits = [
      %{
        root_chain_txhash: Crypto.hash(<<1000::256>>),
        log_index: 1,
        call_data: %{utxo_pos: Utxo.Position.encode(Utxo.position(1, 0, 0))}
      },
      %{
        root_chain_txhash: Crypto.hash(<<1000::256>>),
        log_index: 1,
        call_data: %{utxo_pos: Utxo.Position.encode(Utxo.position(1, 0, 0))}
      }
    ]

    assert :ok = DB.EthEvent.insert_exits!(exits)
  end

  # insert deposits: creates deposit event and utxo
  # insert deposits: creates deposits and retrieves them by hash", %{alice: alice} do
  # Writes of deposits are idempotent

  describe "DB.EthEvent.insert_deposits!/1" do
    @tag fixtures: [:phoenix_ecto_sandbox]
    test "creates deposit events and the events' corresponding utxo" do
      deposits = Factory.deposits_params(3)

      assert :ok = DB.EthEvent.insert_deposits!(deposits)

      assert_deposits_ethevents(deposits)
    end
  end

  describe "DB.EthEvent.insert_exits!/1" do
    @tag fixtures: [:phoenix_ecto_sandbox]
    test "insert exits: creates exit event for utxo" do
      deposits = Factory.deposits_params(1)

      DB.EthEvent.insert_deposits!(deposits)
      deposit_ethevents = DB.EthEvent.get_by_composite_pks(deposits)

      exit_utxos_params = Factory.exits_params(deposit_ethevents)

      assert :ok = DB.EthEvent.insert_exits!(exit_utxos_params)
      exit_ethevents = DB.EthEvent.get_by_composite_pks(exit_utxos_params)

      assert_exited_utxos(exit_utxos_params, deposit_ethevents, exit_ethevents)
    end
  end

  def assert_deposits_ethevents(deposits) do
    ethevents = DB.EthEvent.get_by_composite_pks(deposits)

    assert length(deposits) == length(ethevents)

    Enum.each(Enum.zip(deposits, ethevents), fn {deposit, ethevent} ->
      assert_deposit_ethevent(deposit, ethevent)
    end)
  end

  def assert_deposit_ethevent(deposit, ethevent) do
    assert deposit.root_chain_txhash == ethevent.root_chain_txhash
    assert deposit.log_index == ethevent.log_index

    assert ethevent.root_chain_txhash_event ==
             DB.EthEvent.generate_root_chain_txhash_event(ethevent.root_chain_txhash, ethevent.log_index)

    assert ethevent.event_type == :deposit

    assert ethevent.inserted_at != nil
    assert DateTime.compare(ethevent.inserted_at, ethevent.updated_at) == :eq

    assert length(ethevent.txoutputs) == 1

    [txoutput | _] = ethevent.txoutputs

    assert deposit.blknum == txoutput.blknum
    assert deposit.owner == txoutput.owner
    assert deposit.currency == txoutput.currency
    assert deposit.amount == txoutput.amount

    assert txoutput.creating_transaction == nil
    assert txoutput.creating_txhash == nil

    assert txoutput.spending_transaction == nil
    assert txoutput.spending_txhash == nil
    assert txoutput.spending_tx_oindex == nil

    assert txoutput.txindex == 0
    assert txoutput.oindex == 0

    assert txoutput.child_chain_utxohash ==
             DB.TxOutput.generate_child_chain_utxohash(
               Utxo.position(txoutput.blknum, txoutput.txindex, txoutput.oindex)
             )

    assert txoutput.proof == nil

    assert txoutput.inserted_at != nil
    assert DateTime.compare(txoutput.inserted_at, txoutput.updated_at) == :eq

    # check the association table
    ethevent_txoutput =
      DB.Repo.get_by!(
        DB.EthEventsTxOutputs,
        root_chain_txhash_event: ethevent.root_chain_txhash_event,
        child_chain_utxohash: txoutput.child_chain_utxohash
      )

    assert ethevent_txoutput.root_chain_txhash_event == ethevent.root_chain_txhash_event
    assert ethevent_txoutput.child_chain_utxohash == txoutput.child_chain_utxohash

    assert ethevent_txoutput.inserted_at != nil
    assert DateTime.compare(ethevent_txoutput.inserted_at, ethevent_txoutput.updated_at) == :eq
  end

  def assert_exited_utxos(exit_utxos_params, deposit_ethevents, exit_ethevents) do
    assert length(exit_utxos_params) == length(deposit_ethevents)
    assert length(exit_utxos_params) == length(exit_ethevents)

    Enum.each(Enum.zip([exit_utxos_params, deposit_ethevents, exit_ethevents]), fn {exit_utxo_params, deposit_ethevent,
                                                                                    exit_ethevent} ->
      assert_exited_utxo(exit_utxo_params, deposit_ethevent, exit_ethevent)
    end)
  end

  def assert_exited_utxo(exit_utxo_params, deposit_ethevent, exit_ethevent) do
    {:ok, {:utxo_position, blknum, txindex, oindex}} = Utxo.Position.decode(exit_utxo_params.call_data.utxo_pos)

    txoutput = DB.TxOutput.get_by_position(Utxo.position(blknum, txindex, oindex))

    assert length(txoutput.ethevents) == 2

    # assert exit_utxo_params.root_chain_txhash == ethevent.root_chain_txhash
    # assert exit_utxo_params.log_index == ethevent.log_index

    assert exit_ethevent.event_type == :standard_exit

    assert exit_ethevent.inserted_at != nil
    assert DateTime.compare(deposit_ethevent.inserted_at, exit_ethevent.inserted_at) == :lt
    assert DateTime.compare(exit_ethevent.inserted_at, exit_ethevent.updated_at) == :eq

    # an already spent utxo cannot be exited
    assert txoutput.spending_transaction == nil
    assert txoutput.spending_txhash == nil
    assert txoutput.spending_tx_oindex == nil

    assert txoutput.txindex == 0
    assert txoutput.oindex == 0

    assert txoutput.proof == nil

    assert txoutput.child_chain_utxohash ==
             DB.TxOutput.generate_child_chain_utxohash(
               Utxo.position(txoutput.blknum, txoutput.txindex, txoutput.oindex)
             )

    assert txoutput.inserted_at != nil
    assert DateTime.compare(txoutput.inserted_at, txoutput.updated_at) == :eq

    # check the association table
    txoutput_ethevent_deposit =
      DB.Repo.get_by!(
        DB.EthEventsTxOutputs,
        root_chain_txhash_event: deposit_ethevent.root_chain_txhash_event,
        child_chain_utxohash: txoutput.child_chain_utxohash
      )

    txoutput_ethevent_standard_exit =
      DB.Repo.get_by!(
        DB.EthEventsTxOutputs,
        root_chain_txhash_event: exit_ethevent.root_chain_txhash_event,
        child_chain_utxohash: txoutput.child_chain_utxohash
      )

    assert txoutput_ethevent_deposit.inserted_at != nil
    assert DateTime.compare(txoutput_ethevent_deposit.inserted_at, txoutput_ethevent_deposit.updated_at) == :eq
    assert DateTime.compare(txoutput_ethevent_deposit.inserted_at, txoutput_ethevent_standard_exit.inserted_at) == :lt

    assert DateTime.compare(txoutput_ethevent_standard_exit.inserted_at, txoutput_ethevent_standard_exit.updated_at) ==
             :eq

    query =
      from(
        et in DB.EthEventsTxOutputs,
        where: et.child_chain_utxohash == ^txoutput.child_chain_utxohash
      )

    assert length(DB.Repo.all(query)) == length(txoutput.ethevents)
  end
end

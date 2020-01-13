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

  alias OMG.Utxo
  alias OMG.WatcherInfo.DB

  import OMG.WatcherInfo.Factory

  require Utxo

  describe "DB.EthEvent.insert_deposits!/1" do
    @tag fixtures: [:phoenix_ecto_sandbox]
    test "creates deposit events and the events' corresponding utxo" do
      blocks = insert_list(3, :block)
      deposits = Enum.map(blocks, fn block -> deposit_params(block.blknum) end)

      assert DB.EthEvent.insert_deposits!(deposits) == :ok

      assert_deposit_ethevents(deposits)
    end

    @tag fixtures: [:phoenix_ecto_sandbox]
    test "inserting duplicate deposits results in an error and has no effect on the DB" do
      block = insert(:block)
      %{root_chain_txhash: root_chain_txhash, log_index: log_index} = deposit = deposit_params(block.blknum)

      assert DB.EthEvent.insert_deposits!([deposit]) == :ok
      assert DB.EthEvent.insert_deposits!([deposit]) == :error

      assert %{root_chain_txhash: ^root_chain_txhash, log_index: ^log_index} = DB.EthEvent.get_by(deposit)
    end

    @tag fixtures: [:phoenix_ecto_sandbox]
    test "deposit creation cannot partially fail" do
      block = insert(:block)
      insert(:txoutput, blknum: block.blknum)

      # create a deposit with a txoutput that already exists, which will cause a failure
      deposit = deposit_params(block.blknum)

      assert DB.EthEvent.insert_deposits!([deposit]) == :error

      # insert of txoutput failed, so there should not be an ethevent as the entire transaction
      # was rolled back
      assert DB.EthEvent.get_by(deposit) == nil
    end
  end

  describe "DB.EthEvent.insert_standard_exits!/1" do
    @tag fixtures: [:phoenix_ecto_sandbox]
    test "insert standard exits: creates exit event for an unspent utxo" do
      block = build(:block)
      deposit = deposit_params(block.blknum)

      DB.EthEvent.insert_deposits!([deposit])
      deposit_ethevents = DB.EthEvent.get_by([deposit])

      exit_utxos_params =
        Enum.map(deposit_ethevents, fn deposit_ethevent ->
          exit_params_from_ethevent(deposit_ethevent)
        end)

      assert DB.EthEvent.insert_exits!(exit_utxos_params) == :ok
      exit_ethevents = DB.EthEvent.get_by(exit_utxos_params)

      utxo_positions =
        Enum.map(exit_utxos_params, fn exit_utxos_param ->
          exit_utxos_param.call_data.utxo_pos
        end)

      assert_standard_exit_ethevents(utxo_positions, deposit_ethevents, exit_ethevents)
    end

    @tag fixtures: [:phoenix_ecto_sandbox]
    test "ethevents_txoutputs relationship should have correct information after multiple ethevents on a single txoutput" do
      block = build(:block)
      deposit_params = deposit_params(block.blknum)

      assert DB.EthEvent.insert_deposits!([deposit_params]) == :ok

      deposit_ethevent = DB.EthEvent.get_by(deposit_params)
      [deposit_txoutput | _] = deposit_ethevent.txoutputs

      # store the original association row
      ethevent_txoutput =
        DB.Repo.get_by!(
          DB.EthEventsTxOutputs,
          root_chain_txhash_event: deposit_ethevent.root_chain_txhash_event,
          child_chain_utxohash: deposit_txoutput.child_chain_utxohash
        )

      exit_params = exit_params_from_txoutput(deposit_txoutput)

      assert DB.EthEvent.insert_exits!([exit_params]) == :ok

      exit_ethevent = DB.EthEvent.get_by(exit_params)
      [exit_txoutput | _] = exit_ethevent.txoutputs

      assert deposit_txoutput.child_chain_utxohash == exit_txoutput.child_chain_utxohash

      updated_ethevent_txoutput =
        DB.Repo.get_by!(
          DB.EthEventsTxOutputs,
          root_chain_txhash_event: deposit_ethevent.root_chain_txhash_event,
          child_chain_utxohash: exit_txoutput.child_chain_utxohash
        )

      assert ethevent_txoutput.root_chain_txhash_event == updated_ethevent_txoutput.root_chain_txhash_event
      assert ethevent_txoutput.child_chain_utxohash == updated_ethevent_txoutput.child_chain_utxohash
      assert DateTime.compare(ethevent_txoutput.inserted_at, updated_ethevent_txoutput.inserted_at) == :eq
      assert DateTime.compare(ethevent_txoutput.updated_at, updated_ethevent_txoutput.updated_at) == :eq

      assert DB.Repo.one(
               from(et in DB.EthEventsTxOutputs,
                 where: et.child_chain_utxohash == ^deposit_txoutput.child_chain_utxohash,
                 select: count(et.child_chain_utxohash)
               )
             ) == 2

      assert DB.Repo.one(
               from(et in DB.EthEventsTxOutputs,
                 where: et.root_chain_txhash_event == ^deposit_ethevent.root_chain_txhash_event,
                 select: count(et.root_chain_txhash_event)
               )
             ) == 1

      assert DB.Repo.one(
               from(et in DB.EthEventsTxOutputs,
                 where: et.root_chain_txhash_event == ^exit_ethevent.root_chain_txhash_event,
                 select: count(et.root_chain_txhash_event)
               )
             ) == 1
    end
  end

  def assert_deposit_ethevents(deposits) do
    ethevents = DB.EthEvent.get_by(deposits)

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

    assert_deposit_txoutput(deposit, txoutput)
  end

  def assert_deposit_txoutput(deposit, txoutput) do
    assert deposit.blknum == txoutput.blknum
    assert deposit.owner == txoutput.owner
    assert deposit.currency == txoutput.currency
    assert deposit.amount == txoutput.amount

    # a fresh deposit should have no creating/spending transaction data
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

    root_chain_txhash_event = DB.EthEvent.generate_root_chain_txhash_event(deposit.root_chain_txhash, deposit.log_index)

    # check the association table
    ethevent_txoutput =
      DB.Repo.get_by!(
        DB.EthEventsTxOutputs,
        root_chain_txhash_event: root_chain_txhash_event,
        child_chain_utxohash: txoutput.child_chain_utxohash
      )

    assert ethevent_txoutput.root_chain_txhash_event == root_chain_txhash_event
    assert ethevent_txoutput.child_chain_utxohash == txoutput.child_chain_utxohash

    assert ethevent_txoutput.inserted_at != nil
    assert DateTime.compare(ethevent_txoutput.inserted_at, ethevent_txoutput.updated_at) == :eq
  end

  def assert_standard_exit_ethevents(utxo_positions, deposit_ethevents, exit_ethevents) do
    assert length(utxo_positions) == length(deposit_ethevents)
    assert length(utxo_positions) == length(exit_ethevents)

    Enum.each(
      Enum.zip([utxo_positions, deposit_ethevents, exit_ethevents]),
      fn {utxo_position, deposit_ethevent, exit_ethevent} ->
        assert_standard_exit_ethevent(utxo_position, deposit_ethevent, exit_ethevent)
      end
    )
  end

  def assert_standard_exit_ethevent(utxo_pos, deposit_ethevent, exit_ethevent) do
    {:ok, {:utxo_position, blknum, txindex, oindex}} = Utxo.Position.decode(utxo_pos)

    txoutput = DB.TxOutput.get_by_position(Utxo.position(blknum, txindex, oindex))

    Enum.each(txoutput.ethevents, fn ethevent ->
      event = DB.EthEvent.get_by(ethevent)
      assert length(event.txoutputs) == 1
    end)

    assert exit_ethevent.event_type == :standard_exit

    assert exit_ethevent.inserted_at != nil
    assert DateTime.compare(deposit_ethevent.inserted_at, exit_ethevent.inserted_at) == :lt
    assert DateTime.compare(exit_ethevent.inserted_at, exit_ethevent.updated_at) == :eq

    assert_standard_exit_txoutput(
      txoutput,
      deposit_ethevent.root_chain_txhash_event,
      exit_ethevent.root_chain_txhash_event
    )
  end

  def assert_standard_exit_txoutput(txoutput, deposit_root_chain_txhash_event, exit_root_chain_txhash_event) do
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
        root_chain_txhash_event: deposit_root_chain_txhash_event,
        child_chain_utxohash: txoutput.child_chain_utxohash
      )

    txoutput_ethevent_standard_exit =
      DB.Repo.get_by!(
        DB.EthEventsTxOutputs,
        root_chain_txhash_event: exit_root_chain_txhash_event,
        child_chain_utxohash: txoutput.child_chain_utxohash
      )

    assert txoutput_ethevent_deposit.inserted_at != nil
    assert DateTime.compare(txoutput_ethevent_deposit.inserted_at, txoutput_ethevent_deposit.updated_at) == :eq
    assert DateTime.compare(txoutput_ethevent_deposit.inserted_at, txoutput_ethevent_standard_exit.inserted_at) == :lt

    assert DateTime.compare(txoutput_ethevent_standard_exit.inserted_at, txoutput_ethevent_standard_exit.updated_at) ==
             :eq

    assert DB.Repo.one(
             from(et in DB.EthEventsTxOutputs,
               where: et.child_chain_utxohash == ^txoutput.child_chain_utxohash,
               select: count(et.child_chain_utxohash)
             )
           ) == 2
  end
end

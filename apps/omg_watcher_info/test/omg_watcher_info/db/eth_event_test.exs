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
  alias OMG.WatcherInfo.DB.TxOutputTest

  import OMG.WatcherInfo.Factory

  require Utxo

  describe "DB.EthEvent.insert_deposits!/1" do
    @tag fixtures: [:phoenix_ecto_sandbox]
    test "creates deposit events and the events' corresponding utxos" do
      blocks = insert_list(3, :block)
      insert_deposits_params = Enum.map(blocks, fn block -> deposit_params(block.blknum) end)

      assert DB.EthEvent.insert_deposits!(insert_deposits_params) == :ok

      Enum.each(insert_deposits_params, fn insert_deposit_params ->
        {:ok, deposit_ethevent} =
          insert_deposit_params
          |> to_fetch_by_params([:root_chain_txhash, :log_index])
          |> DB.EthEvent.fetch_by()

        assert_deposit_ethevent(insert_deposit_params, deposit_ethevent)
      end)
    end

    @tag fixtures: [:phoenix_ecto_sandbox]
    test "inserting duplicate deposits results in an error and has no effect on the DB" do
      block = insert(:block)
      insert_deposit_params = deposit_params(block.blknum)

      assert DB.EthEvent.insert_deposits!([insert_deposit_params]) == :ok
      assert DB.EthEvent.insert_deposits!([insert_deposit_params]) == :error
    end

    @tag fixtures: [:phoenix_ecto_sandbox]
    test "deposit creation cannot partially fail" do
      block = insert(:block)
      insert(:txoutput, blknum: block.blknum)

      # create a deposit with a txoutput that already exists, which will cause a failure
      insert_deposit_params = deposit_params(block.blknum)

      assert DB.EthEvent.insert_deposits!([insert_deposit_params]) == :error

      # insert of txoutput failed, so there should not be an ethevent as the entire transaction
      # was rolled back 
      {fetch_status, _} =
        insert_deposit_params
        |> to_fetch_by_params([:root_chain_txhash, :log_index])
        |> DB.EthEvent.fetch_by()

      assert fetch_status == :error
    end
  end

  describe "DB.EthEvent.insert_standard_exits!/1" do
    @tag fixtures: [:phoenix_ecto_sandbox]
    test "insert standard exits: creates exit event for an unspent utxo" do
      block = build(:block)
      insert_deposit_params = deposit_params(block.blknum)

      assert DB.EthEvent.insert_deposits!([insert_deposit_params]) == :ok

      {:ok, deposit_ethevent} =
        insert_deposit_params
        |> to_fetch_by_params([:root_chain_txhash, :log_index])
        |> DB.EthEvent.fetch_by()

      [deposit_txoutput | _] = deposit_ethevent.txoutputs

      exit_utxo_params = exit_params_from_txoutput(deposit_txoutput)

      assert DB.EthEvent.insert_exits!([exit_utxo_params]) == :ok

      {:ok, exit_ethevent} =
        exit_utxo_params
        |> to_fetch_by_params([:root_chain_txhash, :log_index])
        |> DB.EthEvent.fetch_by()

      [exit_txoutput | _] = exit_ethevent.txoutputs

      assert exit_txoutput.blknum == deposit_txoutput.blknum
      assert exit_txoutput.txindex == deposit_txoutput.txindex
      assert exit_txoutput.oindex == deposit_txoutput.oindex

      utxo_pos = [blknum: deposit_txoutput.blknum, txindex: deposit_txoutput.txindex, oindex: deposit_txoutput.oindex]

      {:ok, txoutput} = DB.TxOutput.fetch_by(utxo_pos)

      assert length(txoutput.ethevents) == 2

      assert_standard_exit_ethevent(exit_utxo_params, exit_ethevent)
    end

    @tag fixtures: [:phoenix_ecto_sandbox]
    test "exiting a txoutput that is already spent fails" do
      assert true == false
    end

    @tag fixtures: [:phoenix_ecto_sandbox]
    test "exiting a txoutput that is already exited fails" do
      assert true == false
    end
  end

  describe "DB.EthEventTxOutput many-to-many relationship test" do
    @tag fixtures: [:phoenix_ecto_sandbox]
    test "ethevents_txoutputs relationship should have correct information after multiple ethevents on a single txoutput" do
      block = build(:block)
      insert_deposit_params = deposit_params(block.blknum)

      assert DB.EthEvent.insert_deposits!([insert_deposit_params]) == :ok

      {:ok, deposit_ethevent} =
        insert_deposit_params
        |> to_fetch_by_params([:root_chain_txhash, :log_index])
        |> DB.EthEvent.fetch_by()

      [deposit_txoutput | _] = deposit_ethevent.txoutputs

      # save the original association row for assertions later
      ethevent_txoutput =
        DB.Repo.get_by!(
          DB.EthEventsTxOutputs,
          root_chain_txhash_event: deposit_ethevent.root_chain_txhash_event,
          child_chain_utxohash: deposit_txoutput.child_chain_utxohash
        )

      exit_utxo_params = exit_params_from_txoutput(deposit_txoutput)

      assert DB.EthEvent.insert_exits!([exit_utxo_params]) == :ok

      {:ok, exit_ethevent} =
        exit_utxo_params
        |> to_fetch_by_params([:root_chain_txhash, :log_index])
        |> DB.EthEvent.fetch_by()

      [exit_txoutput | _] = exit_ethevent.txoutputs

      assert deposit_txoutput.child_chain_utxohash == exit_txoutput.child_chain_utxohash

      updated_ethevent_txoutput =
        DB.Repo.get_by!(
          DB.EthEventsTxOutputs,
          root_chain_txhash_event: exit_ethevent.root_chain_txhash_event,
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

  def assert_deposit_ethevent(insert_deposit_params, ethevent) do
    assert insert_deposit_params.root_chain_txhash == ethevent.root_chain_txhash
    assert insert_deposit_params.log_index == ethevent.log_index

    assert ethevent.root_chain_txhash_event ==
             DB.EthEvent.generate_root_chain_txhash_event(ethevent.root_chain_txhash, ethevent.log_index)

    assert ethevent.event_type == :deposit

    assert ethevent.inserted_at != nil
    assert DateTime.compare(ethevent.inserted_at, ethevent.updated_at) == :eq

    assert length(ethevent.txoutputs) == 1

    [txoutput | _] = ethevent.txoutputs

    assert_deposit_txoutput(insert_deposit_params, txoutput)
  end

  def assert_standard_exit_ethevent(exit_utxo_params, ethevent) do
    assert ethevent.event_type == :standard_exit

    assert ethevent.inserted_at != nil
    assert DateTime.compare(ethevent.inserted_at, ethevent.updated_at) == :eq

    {:ok, {:utxo_position, blknum, txindex, oindex}} = Utxo.Position.decode(exit_utxo_params.call_data.utxo_pos)

    {:ok, txoutput} = DB.TxOutput.fetch_by(blknum: blknum, txindex: txindex, oindex: oindex)

    Enum.each(txoutput.ethevents, fn ethevent ->
      {:ok, event} = DB.EthEvent.fetch_by(root_chain_txhash: ethevent.root_chain_txhash, log_index: ethevent.log_index)
      assert length(event.txoutputs) == 1
    end)

    assert_standard_exit_txoutput(exit_utxo_params, txoutput)
  end

  def assert_deposit_txoutput(insert_deposit_params, txoutput) do
    assert insert_deposit_params.blknum == txoutput.blknum
    assert insert_deposit_params.owner == txoutput.owner
    assert insert_deposit_params.currency == txoutput.currency
    assert insert_deposit_params.amount == txoutput.amount

    # a fresh deposit should have no creating/spending transaction data
    assert txoutput.creating_txhash == nil

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

    root_chain_txhash_event =
      DB.EthEvent.generate_root_chain_txhash_event(
        insert_deposit_params.root_chain_txhash,
        insert_deposit_params.log_index
      )

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

  def assert_standard_exit_txoutput(exit_utxo_params, txoutput) do
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
    #   txoutput_ethevent_deposit =
    #     DB.Repo.get_by!(
    #       DB.EthEventsTxOutputs,
    #       root_chain_txhash_event: exit_ethevent.,
    #       child_chain_utxohash: txoutput.child_chain_utxohash
    #     )

    #   txoutput_ethevent_standard_exit =
    #     DB.Repo.get_by!(
    #       DB.EthEventsTxOutputs,
    #       root_chain_txhash_event: exit_root_chain_txhash_event,
    #       child_chain_utxohash: txoutput.child_chain_utxohash
    #     )

    #   assert txoutput_ethevent_deposit.inserted_at != nil
    #   assert DateTime.compare(txoutput_ethevent_deposit.inserted_at, txoutput_ethevent_deposit.updated_at) == :eq
    #   assert DateTime.compare(txoutput_ethevent_deposit.inserted_at, txoutput_ethevent_standard_exit.inserted_at) == :lt

    #   assert DateTime.compare(txoutput_ethevent_standard_exit.inserted_at, txoutput_ethevent_standard_exit.updated_at) ==
    #            :eq

    #   assert DB.Repo.one(
    #            from(et in DB.EthEventsTxOutputs,
    #              where: et.child_chain_utxohash == ^txoutput.child_chain_utxohash,
    #              select: count(et.child_chain_utxohash)
    #            )
    #          ) == 2
  end
end

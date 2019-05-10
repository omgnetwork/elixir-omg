# Copyright 2018 OmiseGO Pte Ltd
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

defmodule OMG.Watcher.ExitProcessor.Core.StandardExitChallengeTest do
  @moduledoc """
  Test of the logic of exit processor, in the area of producing challenges to standard exits
  """

  use ExUnit.Case, async: true

  alias OMG.Block
  alias OMG.State.Transaction
  alias OMG.TestHelper
  alias OMG.Utxo
  alias OMG.Watcher.ExitProcessor
  alias OMG.Watcher.ExitProcessor.Core

  require Utxo

  import OMG.Watcher.ExitProcessor.TestHelper

  @eth OMG.Eth.RootChain.eth_pseudo_address()

  @deposit_blknum1 1
  @deposit_blknum2 2
  @blknum 1_000

  @utxo_pos_tx Utxo.position(@blknum, 0, 0)
  @utxo_pos_deposit Utxo.position(@deposit_blknum1, 0, 0)

  @deposit_input2 {@deposit_blknum2, 0, 0}

  @exit_id 123

  setup do
    {:ok, empty} = Core.init([], [], [])
    %{processor_empty: empty, alice: TestHelper.generate_entity(), bob: TestHelper.generate_entity()}
  end

  describe "Core.determine_standard_challenge_queries" do
    test "asks for correct data: deposit utxo double spent in IFE",
         %{alice: alice, processor_empty: processor} do
      ife_tx = TestHelper.create_recovered([{@deposit_blknum1, 0, 0, alice}], @eth, [])
      processor = processor |> start_se_from_deposit(@utxo_pos_deposit, alice) |> start_ife_from(ife_tx)

      assert {:ok, %ExitProcessor.Request{se_creating_blocks_to_get: [], se_spending_blocks_to_get: []}} =
               %ExitProcessor.Request{se_exiting_pos: @utxo_pos_deposit}
               |> Core.determine_standard_challenge_queries(processor)
    end

    test "asks for correct data: deposit utxo double spent not in IFE",
         %{alice: alice, processor_empty: processor} do
      processor = processor |> start_se_from_deposit(@utxo_pos_deposit, alice)

      assert {:ok,
              %ExitProcessor.Request{se_creating_blocks_to_get: [], se_spending_blocks_to_get: [@utxo_pos_deposit]}} =
               %ExitProcessor.Request{se_exiting_pos: @utxo_pos_deposit}
               |> Core.determine_standard_challenge_queries(processor)
    end

    test "asks for correct data: tx utxo double spent in an IFE",
         %{alice: alice, processor_empty: processor} do
      ife_tx = TestHelper.create_recovered([{@blknum, 0, 0, alice}], @eth, [])
      processor = processor |> start_se_from_block_tx(@utxo_pos_tx, alice) |> start_ife_from(ife_tx)

      assert {:ok, %ExitProcessor.Request{se_creating_blocks_to_get: [@blknum], se_spending_blocks_to_get: []}} =
               %ExitProcessor.Request{se_exiting_pos: @utxo_pos_tx}
               |> Core.determine_standard_challenge_queries(processor)
    end

    test "asks for correct data: tx utxo double spent not in IFE",
         %{alice: alice, processor_empty: processor} do
      processor = processor |> start_se_from_block_tx(@utxo_pos_tx, alice)

      assert {:ok,
              %ExitProcessor.Request{se_creating_blocks_to_get: [@blknum], se_spending_blocks_to_get: [@utxo_pos_tx]}} =
               %ExitProcessor.Request{se_exiting_pos: @utxo_pos_tx}
               |> Core.determine_standard_challenge_queries(processor)
    end

    test "stops immediately, if exit not found",
         %{processor_empty: processor} do
      assert {:error, :exit_not_found} =
               %ExitProcessor.Request{se_exiting_pos: @utxo_pos_tx}
               |> Core.determine_standard_challenge_queries(processor)
    end
  end

  describe "Core.determine_exit_txbytes" do
    test "produces valid exit txbytes for exits from deposits",
         %{alice: alice, processor_empty: processor} do
      tx = Transaction.new([], [{alice.addr, @eth, 10}])
      deposit_txbytes = Transaction.raw_txbytes(tx)
      processor = processor |> start_se_from(tx, @utxo_pos_deposit)

      assert %ExitProcessor.Request{se_exit_id_to_get: ^deposit_txbytes} =
               %ExitProcessor.Request{se_exiting_pos: @utxo_pos_deposit}
               |> Core.determine_exit_txbytes(processor)
    end

    test "produces valid exit txbytes for exits from txs in child blocks",
         %{alice: alice, processor_empty: processor} do
      creating_recovered = TestHelper.create_recovered([{@deposit_blknum2, 0, 0, alice}], @eth, [{alice, 10}])
      creating_txbytes = Transaction.raw_txbytes(creating_recovered)
      processor = processor |> start_se_from(creating_recovered, @utxo_pos_tx)

      assert %ExitProcessor.Request{se_exit_id_to_get: ^creating_txbytes} =
               %ExitProcessor.Request{
                 se_exiting_pos: @utxo_pos_tx,
                 se_creating_blocks_result: [Block.hashed_txs_at([creating_recovered], @blknum)]
               }
               |> Core.determine_exit_txbytes(processor)
    end

    test "crashes if asked to produce exit txbytes when creating block not found or db response empty",
         %{alice: alice, processor_empty: processor} do
      processor = processor |> start_se_from_block_tx(@utxo_pos_tx, alice)

      assert_raise(MatchError, fn ->
        %ExitProcessor.Request{se_exiting_pos: @utxo_pos_tx, se_creating_blocks_result: []}
        |> Core.determine_exit_txbytes(processor)
      end)

      assert_raise(MatchError, fn ->
        %ExitProcessor.Request{se_exiting_pos: @utxo_pos_tx, se_creating_blocks_result: [:not_found]}
        |> Core.determine_exit_txbytes(processor)
      end)
    end
  end

  describe "Core.create_challenge" do
    test "creates challenge: deposit utxo double spent in IFE",
         %{alice: alice, processor_empty: processor} do
      ife_tx = TestHelper.create_recovered([{@deposit_blknum1, 0, 0, alice}], @eth, [])
      {txbytes, alice_sig} = get_bytes_sig(ife_tx)
      processor = processor |> start_se_from_deposit(@utxo_pos_deposit, alice) |> start_ife_from(ife_tx)

      assert {:ok, %{exit_id: @exit_id, input_index: 0, txbytes: ^txbytes, sig: ^alice_sig}} =
               %ExitProcessor.Request{se_exiting_pos: @utxo_pos_deposit, se_exit_id_result: @exit_id}
               |> Core.create_challenge(processor)
    end

    test "creates challenge: deposit utxo double spent not in IFE",
         %{alice: alice, processor_empty: processor} do
      processor = processor |> start_se_from_deposit(@utxo_pos_deposit, alice)

      recovered_spend = TestHelper.create_recovered([{1, 0, 0, alice}], @eth, [{alice, 10}])
      {txbytes, alice_sig} = get_bytes_sig(recovered_spend)

      assert {:ok, %{exit_id: @exit_id, input_index: 0, txbytes: ^txbytes, sig: ^alice_sig}} =
               %ExitProcessor.Request{
                 se_exiting_pos: @utxo_pos_deposit,
                 se_spending_blocks_result: [Block.hashed_txs_at([recovered_spend], @blknum)],
                 se_exit_id_result: @exit_id
               }
               |> Core.create_challenge(processor)
    end

    test "creates challenge: tx utxo double spent in an IFE",
         %{alice: alice, processor_empty: processor} do
      # quite similar to the deposit utxo case, but leaving the test in for completeness
      ife_tx = TestHelper.create_recovered([{@blknum, 0, 0, alice}], @eth, [])
      {txbytes, alice_sig} = get_bytes_sig(ife_tx)
      processor = processor |> start_se_from_block_tx(@utxo_pos_tx, alice) |> start_ife_from(ife_tx)

      assert {:ok, %{exit_id: @exit_id, input_index: 0, txbytes: ^txbytes, sig: ^alice_sig}} =
               %ExitProcessor.Request{se_exiting_pos: @utxo_pos_tx, se_exit_id_result: @exit_id}
               |> Core.create_challenge(processor)
    end

    test "creates challenge: tx utxo double spent not in IFE",
         %{alice: alice, processor_empty: processor} do
      # quite similar to the deposit utxo case, but leaving the test in for completeness
      processor = processor |> start_se_from_block_tx(@utxo_pos_tx, alice)

      recovered_spend = TestHelper.create_recovered([{@blknum, 0, 0, alice}], @eth, [{alice, 10}])
      {txbytes, alice_sig} = get_bytes_sig(recovered_spend)

      assert {:ok, %{exit_id: @exit_id, input_index: 0, txbytes: ^txbytes, sig: ^alice_sig}} =
               %ExitProcessor.Request{
                 se_exiting_pos: @utxo_pos_tx,
                 se_spending_blocks_result: [Block.hashed_txs_at([recovered_spend], @blknum)],
                 se_exit_id_result: @exit_id
               }
               |> Core.create_challenge(processor)
    end

    test "creates challenge: tx utxo double spent on input various positions",
         %{alice: alice, processor_empty: processor} do
      processor = processor |> start_se_from_block_tx(@utxo_pos_tx, alice)

      input = {@blknum, 0, 0, alice}

      recovered_spends = [
        TestHelper.create_recovered([input], @eth, [{alice, 10}]),
        TestHelper.create_recovered([{1, 0, 0, alice}, input], @eth, [{alice, 10}]),
        TestHelper.create_recovered([{1, 0, 0, alice}, {2, 0, 0, alice}, input], @eth, [{alice, 10}]),
        TestHelper.create_recovered([{1, 0, 0, alice}, {2, 0, 0, alice}, {3, 0, 0, alice}, input], @eth, [{alice, 10}])
      ]

      recovered_spends
      |> Enum.with_index()
      |> Enum.map(fn {recovered_spend, expected_index} ->
        {txbytes, alice_sig} = get_bytes_sig(recovered_spend)

        assert {:ok, %{exit_id: @exit_id, input_index: ^expected_index, txbytes: ^txbytes, sig: ^alice_sig}} =
                 %ExitProcessor.Request{
                   se_exiting_pos: @utxo_pos_tx,
                   se_spending_blocks_result: [Block.hashed_txs_at([recovered_spend], @blknum)],
                   se_exit_id_result: @exit_id
                 }
                 |> Core.create_challenge(processor)
      end)
    end

    test "creates challenge: tx utxo double spent signed_by different signers",
         %{alice: alice, bob: bob, processor_empty: processor} do
      tx1 = Transaction.new([@deposit_input2], [{alice.addr, @eth, 10}])
      tx2 = Transaction.new([@deposit_input2], [{bob.addr, @eth, 10}])
      processor1 = processor |> start_se_from(tx1, @utxo_pos_tx)
      processor2 = processor |> start_se_from(tx2, @utxo_pos_tx)

      recovered_spends = [
        TestHelper.create_recovered([{1, 0, 0, bob}, {@blknum, 0, 0, alice}], @eth, [{alice, 10}]),
        TestHelper.create_recovered([{1, 0, 0, alice}, {@blknum, 0, 0, bob}], @eth, [{alice, 10}])
      ]

      recovered_spends
      |> Enum.zip([processor1, processor2])
      |> Enum.map(fn {recovered_spend, processor} ->
        {txbytes, second_sig} = get_bytes_sig(recovered_spend, 1)

        assert {:ok, %{exit_id: @exit_id, input_index: 1, txbytes: ^txbytes, sig: ^second_sig}} =
                 %ExitProcessor.Request{
                   se_exiting_pos: @utxo_pos_tx,
                   se_spending_blocks_result: [Block.hashed_txs_at([recovered_spend], @blknum)],
                   se_exit_id_result: @exit_id
                 }
                 |> Core.create_challenge(processor)
      end)
    end

    test "creates challenge: both utxos spent don't interfere",
         %{alice: alice, processor_empty: processor} do
      tx = Transaction.new([@deposit_input2], [{alice.addr, @eth, 10}, {alice.addr, @eth, 10}])
      processor = processor |> start_se_from(tx, @utxo_pos_tx)

      recovered_spend = TestHelper.create_recovered([{@blknum, 0, 0, alice}], @eth, [{alice, 10}])
      recovered_spend2 = TestHelper.create_recovered([{@blknum, 0, 1, alice}], @eth, [{alice, 10}])
      {txbytes, alice_sig} = get_bytes_sig(recovered_spend)

      assert {:ok, %{exit_id: @exit_id, input_index: 0, txbytes: ^txbytes, sig: ^alice_sig}} =
               %ExitProcessor.Request{
                 se_exiting_pos: @utxo_pos_tx,
                 se_spending_blocks_result: [Block.hashed_txs_at([recovered_spend, recovered_spend2], @blknum)],
                 se_exit_id_result: @exit_id
               }
               |> Core.create_challenge(processor)
    end

    test "creates challenge: tx utxo double spent in both block and IFE don't interfere",
         %{alice: alice, processor_empty: processor} do
      ife_tx = TestHelper.create_recovered([{@blknum, 0, 0, alice}], @eth, [])
      {txbytes, alice_sig} = get_bytes_sig(ife_tx)
      processor = processor |> start_se_from_block_tx(@utxo_pos_tx, alice) |> start_ife_from(ife_tx)

      # same tx spends in both
      assert {:ok, %{exit_id: @exit_id, input_index: 0, txbytes: ^txbytes, sig: ^alice_sig}} =
               %ExitProcessor.Request{
                 se_exiting_pos: @utxo_pos_tx,
                 se_spending_blocks_result: [Block.hashed_txs_at([ife_tx], @blknum)],
                 se_exit_id_result: @exit_id
               }
               |> Core.create_challenge(processor)

      # different txs spend, block tx takes preference
      recovered_spend2 = TestHelper.create_recovered([{@blknum, 0, 0, alice}], @eth, [{alice, 10}])

      {block_txbytes, alice_sig2} = get_bytes_sig(recovered_spend2)

      assert {:ok, %{exit_id: @exit_id, input_index: 0, txbytes: ^block_txbytes, sig: ^alice_sig2}} =
               %ExitProcessor.Request{
                 se_exiting_pos: @utxo_pos_tx,
                 se_spending_blocks_result: [Block.hashed_txs_at([recovered_spend2], @blknum)],
                 se_exit_id_result: @exit_id
               }
               |> Core.create_challenge(processor)
    end

    test "doesn't create challenge: tx utxo not double spent",
         %{alice: alice, processor_empty: processor} do
      processor = processor |> start_se_from_block_tx(@utxo_pos_tx, alice)

      assert {:error, :utxo_not_spent} =
               %ExitProcessor.Request{
                 se_exiting_pos: @utxo_pos_tx,
                 se_spending_blocks_result: [],
                 se_exit_id_result: @exit_id
               }
               |> Core.create_challenge(processor)

      assert {:error, :utxo_not_spent} =
               %ExitProcessor.Request{
                 se_exiting_pos: @utxo_pos_tx,
                 se_spending_blocks_result: [:not_found],
                 se_exit_id_result: @exit_id
               }
               |> Core.create_challenge(processor)
    end
  end

  defp start_se_from_deposit(processor, exiting_pos, alice) do
    tx = TestHelper.create_recovered([], [{alice, @eth, 10}])
    processor |> start_se_from(tx, exiting_pos)
  end

  defp start_se_from_block_tx(processor, exiting_pos, alice) do
    tx = TestHelper.create_recovered([Tuple.append(@deposit_input2, alice)], [{alice, @eth, 10}])
    processor |> start_se_from(tx, exiting_pos)
  end

  defp get_bytes_sig(tx, sig_idx \\ 0), do: {Transaction.raw_txbytes(tx), Enum.at(tx.signed_tx.sigs, sig_idx)}
end

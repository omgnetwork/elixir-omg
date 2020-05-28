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

defmodule OMG.Watcher.ExitProcessor.StandardExitTest do
  @moduledoc """
  Test of the logic of exit processor, in the area of standard exits
  """

  use OMG.Watcher.ExitProcessor.Case, async: false

  alias OMG.Block
  alias OMG.State.Transaction
  alias OMG.TestHelper
  alias OMG.Utxo
  alias OMG.Watcher.Event
  alias OMG.Watcher.ExitProcessor
  alias OMG.Watcher.ExitProcessor.Core

  require Utxo

  import OMG.Watcher.ExitProcessor.TestHelper,
    only: [start_ife_from: 2, start_se_from: 3, start_se_from: 4, check_validity_filtered: 3]

  @eth OMG.Eth.zero_address()
  @deposit_blknum 1
  @deposit_blknum2 2
  @early_blknum 1_000
  @blknum @early_blknum
  @late_blknum 10_000
  @blknum2 @late_blknum - 1_000

  @utxo_pos_tx Utxo.position(@blknum, 0, 0)
  @utxo_pos_tx2 Utxo.position(@blknum2, 0, 1)
  @utxo_pos_deposit Utxo.position(@deposit_blknum, 0, 0)
  @utxo_pos_deposit2 Utxo.position(@deposit_blknum2, 0, 0)

  @deposit_input2 {@deposit_blknum2, 0, 0}

  # needs to match up with the default from `ExitProcessor.Case` :(
  @exit_id 9876

  @default_min_exit_period_seconds 120
  @default_child_block_interval 1000

  setup do
    {:ok, empty} = Core.init([], [], [], @default_min_exit_period_seconds, @default_child_block_interval)
    db_path = Briefly.create!(directory: true)
    Application.put_env(:omg_db, :path, db_path, persistent: true)
    :ok = OMG.DB.init()
    {:ok, started_apps} = Application.ensure_all_started(:omg_db)

    on_exit(fn ->
      Application.put_env(:omg_db, :path, nil)

      Enum.map(started_apps, fn app -> :ok = Application.stop(app) end)
    end)

    %{processor_empty: empty, alice: TestHelper.generate_entity(), bob: TestHelper.generate_entity()}
  end

  describe "Core.determine_standard_challenge_queries" do
    test "doesn't ask for anything and stops if deposit utxo not spent at all",
         %{alice: alice, processor_empty: processor} do
      processor = processor |> start_se_from_deposit(@utxo_pos_deposit, alice)

      assert {:error, :utxo_not_spent} =
               %ExitProcessor.Request{se_exiting_pos: @utxo_pos_deposit}
               |> Core.determine_standard_challenge_queries(processor, true)
    end

    test "doesn't ask for anything and stops if tx utxo not spent at all",
         %{alice: alice, processor_empty: processor} do
      processor = processor |> start_se_from_block_tx(@utxo_pos_tx, alice)

      assert {:error, :utxo_not_spent} =
               %ExitProcessor.Request{se_exiting_pos: @utxo_pos_tx}
               |> Core.determine_standard_challenge_queries(processor, true)
    end

    test "asks for correct data: deposit utxo double spent in IFE",
         %{alice: alice, processor_empty: processor} do
      ife_tx = TestHelper.create_recovered([{@deposit_blknum, 0, 0, alice}], @eth, [{alice, 1}])
      processor = processor |> start_se_from_deposit(@utxo_pos_deposit, alice) |> start_ife_from(ife_tx)

      assert {:ok, %ExitProcessor.Request{se_spending_blocks_to_get: []}} =
               %ExitProcessor.Request{se_exiting_pos: @utxo_pos_deposit}
               |> Core.determine_standard_challenge_queries(processor, true)
    end

    test "asks for correct data: deposit utxo double spent outside an IFE",
         %{alice: alice, processor_empty: processor} do
      processor = processor |> start_se_from_deposit(@utxo_pos_deposit, alice)

      assert {:ok, %ExitProcessor.Request{se_spending_blocks_to_get: [@utxo_pos_deposit]}} =
               %ExitProcessor.Request{se_exiting_pos: @utxo_pos_deposit}
               |> Core.determine_standard_challenge_queries(processor, false)
    end

    test "asks for correct data: tx utxo double spent in an IFE",
         %{alice: alice, processor_empty: processor} do
      ife_tx = TestHelper.create_recovered([{@blknum, 0, 0, alice}], @eth, [{alice, 1}])
      processor = processor |> start_se_from_block_tx(@utxo_pos_tx, alice) |> start_ife_from(ife_tx)

      assert {:ok, %ExitProcessor.Request{se_spending_blocks_to_get: []}} =
               %ExitProcessor.Request{se_exiting_pos: @utxo_pos_tx}
               |> Core.determine_standard_challenge_queries(processor, true)
    end

    test "asks for correct data: tx utxo double spent outside an IFE",
         %{alice: alice, processor_empty: processor} do
      processor = processor |> start_se_from_block_tx(@utxo_pos_tx, alice)

      assert {:ok, %ExitProcessor.Request{se_spending_blocks_to_get: [@utxo_pos_tx]}} =
               %ExitProcessor.Request{se_exiting_pos: @utxo_pos_tx}
               |> Core.determine_standard_challenge_queries(processor, false)
    end

    test "stops immediately, if exit not found, utxo exists",
         %{processor_empty: processor} do
      assert {:error, :exit_not_found} =
               %ExitProcessor.Request{se_exiting_pos: @utxo_pos_tx}
               |> Core.determine_standard_challenge_queries(processor, true)
    end

    test "stops immediately, if exit not found, utxo doesn't exist",
         %{processor_empty: processor} do
      assert {:error, :exit_not_found} =
               %ExitProcessor.Request{se_exiting_pos: @utxo_pos_tx}
               |> Core.determine_standard_challenge_queries(processor, false)
    end
  end

  describe "Core.create_challenge" do
    test "returns a deposit exiting_tx as part of the challenge response",
         %{alice: alice, processor_empty: processor} do
      exiting_tx = TestHelper.create_recovered([], [{alice, @eth, 10}])
      processor = processor |> start_se_from(exiting_tx, @utxo_pos_deposit)

      recovered_spend = TestHelper.create_recovered([{@deposit_blknum, 0, 0, alice}], @eth, [{alice, 10}])
      {txbytes, _alice_sig} = get_bytes_sig(recovered_spend)
      {exiting_txbytes, _} = get_bytes_sig(exiting_tx)

      assert {:ok, %{exiting_tx: ^exiting_txbytes, txbytes: ^txbytes}} =
               %ExitProcessor.Request{
                 se_exiting_pos: @utxo_pos_deposit,
                 se_spending_blocks_result: [Block.hashed_txs_at([recovered_spend], @blknum)]
               }
               |> Core.create_challenge(processor)
    end

    test "returns a block exiting_tx as part of the challenge response",
         %{alice: alice, processor_empty: processor} do
      exiting_tx = TestHelper.create_recovered([Tuple.append(@deposit_input2, alice)], [{alice, @eth, 10}])
      processor = processor |> start_se_from(exiting_tx, @utxo_pos_tx)

      recovered_spend = TestHelper.create_recovered([{@blknum, 0, 0, alice}], @eth, [{alice, 10}])
      {txbytes, _alice_sig} = get_bytes_sig(recovered_spend)
      {exiting_txbytes, _} = get_bytes_sig(exiting_tx)

      assert {:ok, %{exiting_tx: ^exiting_txbytes, txbytes: ^txbytes}} =
               %ExitProcessor.Request{
                 se_exiting_pos: @utxo_pos_tx,
                 se_spending_blocks_result: [Block.hashed_txs_at([recovered_spend], @late_blknum)]
               }
               |> Core.create_challenge(processor)
    end

    test "creates challenge: deposit utxo double spent in IFE",
         %{alice: alice, processor_empty: processor} do
      ife_tx = TestHelper.create_recovered([{@deposit_blknum, 0, 0, alice}], @eth, [{alice, 1}])
      {txbytes, alice_sig} = get_bytes_sig(ife_tx)
      processor = processor |> start_se_from_deposit(@utxo_pos_deposit, alice) |> start_ife_from(ife_tx)

      assert {:ok, %{exit_id: @exit_id, input_index: 0, txbytes: ^txbytes, sig: ^alice_sig}} =
               %ExitProcessor.Request{se_exiting_pos: @utxo_pos_deposit}
               |> Core.create_challenge(processor)
    end

    test "creates challenge: deposit utxo double spent outside an IFE",
         %{alice: alice, processor_empty: processor} do
      processor = processor |> start_se_from_deposit(@utxo_pos_deposit, alice)

      recovered_spend = TestHelper.create_recovered([{1, 0, 0, alice}], @eth, [{alice, 10}])
      {txbytes, alice_sig} = get_bytes_sig(recovered_spend)

      assert {:ok, %{exit_id: @exit_id, input_index: 0, txbytes: ^txbytes, sig: ^alice_sig}} =
               %ExitProcessor.Request{
                 se_exiting_pos: @utxo_pos_deposit,
                 se_spending_blocks_result: [Block.hashed_txs_at([recovered_spend], @blknum)]
               }
               |> Core.create_challenge(processor)
    end

    test "creates challenge: tx utxo double spent in an IFE",
         %{alice: alice, processor_empty: processor} do
      # quite similar to the deposit utxo case, but leaving the test in for completeness
      ife_tx = TestHelper.create_recovered([{@blknum, 0, 0, alice}], @eth, [{alice, 1}])
      {txbytes, alice_sig} = get_bytes_sig(ife_tx)
      processor = processor |> start_se_from_block_tx(@utxo_pos_tx, alice) |> start_ife_from(ife_tx)

      assert {:ok, %{exit_id: @exit_id, input_index: 0, txbytes: ^txbytes, sig: ^alice_sig}} =
               %ExitProcessor.Request{se_exiting_pos: @utxo_pos_tx}
               |> Core.create_challenge(processor)
    end

    test "creates challenge: tx utxo double spent outside an IFE",
         %{alice: alice, processor_empty: processor} do
      processor = processor |> start_se_from_block_tx(@utxo_pos_tx, alice)

      recovered_spend = TestHelper.create_recovered([{@blknum, 0, 0, alice}], @eth, [{alice, 10}])
      {txbytes, alice_sig} = get_bytes_sig(recovered_spend)

      assert {:ok, %{exit_id: @exit_id, input_index: 0, txbytes: ^txbytes, sig: ^alice_sig}} =
               %ExitProcessor.Request{
                 se_exiting_pos: @utxo_pos_tx,
                 se_spending_blocks_result: [Block.hashed_txs_at([recovered_spend], @blknum)]
               }
               |> Core.create_challenge(processor)
    end

    test "creates challenge: tx utxo double spent outside an IFE, but there is an unrelated IFE open",
         %{alice: alice, processor_empty: processor} do
      unrelated = TestHelper.create_recovered([{@blknum, 10, 0, alice}], @eth, [{alice, 1}])
      processor = processor |> start_se_from_block_tx(@utxo_pos_tx, alice) |> start_ife_from(unrelated)

      recovered_spend = TestHelper.create_recovered([{@blknum, 0, 0, alice}], @eth, [{alice, 10}])
      {txbytes, alice_sig} = get_bytes_sig(recovered_spend)

      assert {:ok, %{exit_id: @exit_id, input_index: 0, txbytes: ^txbytes, sig: ^alice_sig}} =
               %ExitProcessor.Request{
                 se_exiting_pos: @utxo_pos_tx,
                 se_spending_blocks_result: [Block.hashed_txs_at([recovered_spend], @blknum)]
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
                   se_spending_blocks_result: [Block.hashed_txs_at([recovered_spend], @blknum)]
                 }
                 |> Core.create_challenge(processor)
      end)
    end

    test "creates challenge: tx utxo double spent signed_by different signers",
         %{alice: alice, bob: bob, processor_empty: processor} do
      tx1 = Transaction.Payment.new([@deposit_input2], [{alice.addr, @eth, 10}])
      tx2 = Transaction.Payment.new([@deposit_input2], [{bob.addr, @eth, 10}])
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
                   se_spending_blocks_result: [Block.hashed_txs_at([recovered_spend], @blknum)]
                 }
                 |> Core.create_challenge(processor)
      end)
    end

    test "creates challenge: both utxos spent don't interfere",
         %{alice: alice, processor_empty: processor} do
      tx = Transaction.Payment.new([@deposit_input2], [{alice.addr, @eth, 10}, {alice.addr, @eth, 10}])
      processor = processor |> start_se_from(tx, @utxo_pos_tx)

      recovered_spend = TestHelper.create_recovered([{@blknum, 0, 0, alice}], @eth, [{alice, 10}])
      recovered_spend2 = TestHelper.create_recovered([{@blknum, 0, 1, alice}], @eth, [{alice, 10}])
      {txbytes, alice_sig} = get_bytes_sig(recovered_spend)

      assert {:ok, %{exit_id: @exit_id, input_index: 0, txbytes: ^txbytes, sig: ^alice_sig}} =
               %ExitProcessor.Request{
                 se_exiting_pos: @utxo_pos_tx,
                 se_spending_blocks_result: [Block.hashed_txs_at([recovered_spend, recovered_spend2], @blknum)]
               }
               |> Core.create_challenge(processor)
    end

    test "creates challenge: tx utxo double spent in both block and IFE don't interfere",
         %{alice: alice, processor_empty: processor} do
      ife_tx = TestHelper.create_recovered([{@blknum, 0, 0, alice}], @eth, [{alice, 1}])
      {txbytes, alice_sig} = get_bytes_sig(ife_tx)
      processor = processor |> start_se_from_block_tx(@utxo_pos_tx, alice) |> start_ife_from(ife_tx)

      # same tx spends in both
      assert {:ok, %{exit_id: @exit_id, input_index: 0, txbytes: ^txbytes, sig: ^alice_sig}} =
               %ExitProcessor.Request{
                 se_exiting_pos: @utxo_pos_tx,
                 se_spending_blocks_result: [Block.hashed_txs_at([ife_tx], @blknum)]
               }
               |> Core.create_challenge(processor)

      # different txs spend, block tx takes preference
      recovered_spend2 = TestHelper.create_recovered([{@blknum, 0, 0, alice}], @eth, [{alice, 10}])

      {block_txbytes, alice_sig2} = get_bytes_sig(recovered_spend2)

      assert {:ok, %{exit_id: @exit_id, input_index: 0, txbytes: ^block_txbytes, sig: ^alice_sig2}} =
               %ExitProcessor.Request{
                 se_exiting_pos: @utxo_pos_tx,
                 se_spending_blocks_result: [Block.hashed_txs_at([recovered_spend2], @blknum)]
               }
               |> Core.create_challenge(processor)
    end

    test "doesn't create challenge: tx utxo not double spent",
         %{alice: alice, processor_empty: processor} do
      processor = processor |> start_se_from_block_tx(@utxo_pos_tx, alice)

      assert {:error, :utxo_not_spent} =
               %ExitProcessor.Request{se_exiting_pos: @utxo_pos_tx, se_spending_blocks_result: []}
               |> Core.create_challenge(processor)

      assert {:error, :utxo_not_spent} =
               %ExitProcessor.Request{se_exiting_pos: @utxo_pos_tx, se_spending_blocks_result: [:not_found]}
               |> Core.create_challenge(processor)
    end
  end

  describe "Core.check_validity" do
    test "detect invalid standard exit based on utxo missing in main ledger",
         %{processor_empty: processor, alice: alice} do
      exiting_pos = @utxo_pos_tx
      exiting_pos_enc = Utxo.Position.encode(exiting_pos)
      # standard_exit_tx = TestHelper.create_recovered([{@deposit_blknum, 0, 0, alice}], @eth, [{alice, 10}])
      %{signed_tx_bytes: signed_tx_bytes, tx_hash: tx_hash} =
        standard_exit_tx = TestHelper.create_recovered([{@blknum, 0, 0, alice}], @eth, [{alice, 10}])

      request = %ExitProcessor.Request{
        eth_timestamp_now: 5 + :os.system_time(:second),
        blknum_now: @late_blknum,
        utxos_to_check: [exiting_pos],
        utxo_exists_result: [false]
      }

      # before the exit starts
      assert {:ok, []} = Core.check_validity(request, processor)
      # after
      processor = start_se_from(processor, standard_exit_tx, exiting_pos)

      block_updates = [{:put, :block, %{number: @blknum, hash: <<0::160>>, transactions: [signed_tx_bytes]}}]
      spent_blknum_updates = [{:put, :spend, {Utxo.Position.to_input_db_key(@utxo_pos_tx), @blknum}}]
      :ok = OMG.DB.multi_update(block_updates ++ spent_blknum_updates)

      assert {:ok, [%Event.InvalidExit{utxo_pos: ^exiting_pos_enc, spending_txhash: ^tx_hash}]} =
               Core.check_validity(request, processor)
    end

    test "detect old invalid standard exit", %{processor_empty: processor, alice: alice} do
      exiting_pos = @utxo_pos_tx
      exiting_pos_enc = Utxo.Position.encode(exiting_pos)

      %{signed_tx_bytes: signed_tx_bytes, tx_hash: tx_hash} =
        standard_exit_tx = TestHelper.create_recovered([{@blknum, 0, 0, alice}], @eth, [{alice, 10}])

      request = %ExitProcessor.Request{
        eth_timestamp_now: 50 + :os.system_time(:second),
        blknum_now: @late_blknum,
        utxos_to_check: [exiting_pos],
        utxo_exists_result: [false]
      }

      processor = start_se_from(processor, standard_exit_tx, exiting_pos)

      block_updates = [{:put, :block, %{number: @blknum, hash: <<0::160>>, transactions: [signed_tx_bytes]}}]
      spent_blknum_updates = [{:put, :spend, {Utxo.Position.to_input_db_key(@utxo_pos_tx), @blknum}}]
      :ok = OMG.DB.multi_update(block_updates ++ spent_blknum_updates)

      assert {{:error, :unchallenged_exit},
              [
                %Event.UnchallengedExit{utxo_pos: ^exiting_pos_enc, spending_txhash: ^tx_hash},
                %Event.InvalidExit{utxo_pos: ^exiting_pos_enc, spending_txhash: ^tx_hash}
              ]} = Core.check_validity(request, processor)
    end

    test "invalid exits that have been witnessed already inactive don't excite events",
         %{processor_empty: processor, alice: alice} do
      exiting_pos = @utxo_pos_tx
      standard_exit_tx = TestHelper.create_recovered([{@deposit_blknum, 0, 0, alice}], @eth, [{alice, 10}])

      request = %ExitProcessor.Request{
        eth_timestamp_now: 13 + :os.system_time(:second),
        blknum_now: @late_blknum,
        utxos_to_check: [exiting_pos],
        utxo_exists_result: [false]
      }

      processor = processor |> start_se_from(standard_exit_tx, exiting_pos, inactive: true)
      assert {:ok, []} = request |> Core.check_validity(processor)
    end

    test "exits of utxos that couldn't have been seen created yet never excite querying the ledger",
         %{processor_empty: processor, alice: alice} do
      exiting_pos = @utxo_pos_tx2
      standard_exit_tx = TestHelper.create_recovered([{@deposit_blknum, 0, 0, alice}], @eth, [{alice, 1}, {alice, 1}])

      processor = processor |> start_se_from(standard_exit_tx, exiting_pos)

      assert %ExitProcessor.Request{utxos_to_check: []} =
               %ExitProcessor.Request{eth_timestamp_now: 13 + :os.system_time(:second), blknum_now: @early_blknum}
               |> Core.determine_utxo_existence_to_get(processor)
    end

    test "detect invalid standard exit based on ife tx which spends same input",
         %{processor_empty: processor, alice: alice} do
      standard_exit_tx = TestHelper.create_recovered([{@deposit_blknum, 0, 0, alice}], @eth, [{alice, 10}])
      %{tx_hash: tx_hash} = tx = TestHelper.create_recovered([{@blknum, 0, 0, alice}], [{alice, @eth, 1}])
      exiting_pos = @utxo_pos_tx
      exiting_pos_enc = Utxo.Position.encode(exiting_pos)
      processor = processor |> start_se_from(standard_exit_tx, exiting_pos) |> start_ife_from(tx)

      assert {:ok, [%Event.InvalidExit{utxo_pos: ^exiting_pos_enc, spending_txhash: ^tx_hash}]} =
               check_validity_filtered(%ExitProcessor.Request{eth_timestamp_now: 5 + :os.system_time(:second), blknum_now: @late_blknum}, processor,
                 only: [Event.InvalidExit]
               )
    end

    test "ifes and standard exits don't interfere",
         %{alice: alice, processor_empty: processor, transactions: [tx | _]} do
      %{signed_tx_bytes: signed_tx_bytes, tx_hash: tx_hash} =
        standard_exit_tx = TestHelper.create_recovered([{@blknum, 0, 0, alice}], @eth, [{alice, 10}])

      processor = processor |> start_se_from(standard_exit_tx, @utxo_pos_tx) |> start_ife_from(tx)

      assert %{utxos_to_check: [_, Utxo.position(1, 2, 1), @utxo_pos_tx]} =
               exit_processor_request =
               %ExitProcessor.Request{eth_timestamp_now: 5 + :os.system_time(:second), blknum_now: @late_blknum}
               |> Core.determine_utxo_existence_to_get(processor)

      block_updates = [{:put, :block, %{number: @blknum, hash: <<0::160>>, transactions: [signed_tx_bytes]}}]
      spent_blknum_updates = [{:put, :spend, {Utxo.Position.to_input_db_key(@utxo_pos_tx), @blknum}}]
      :ok = OMG.DB.multi_update(block_updates ++ spent_blknum_updates)

      # here it's crucial that the missing utxo related to the ife isn't interpeted as a standard invalid exit
      # that missing utxo isn't enough for any IFE-related event too
      assert {:ok, [%Event.InvalidExit{spending_txhash: ^tx_hash}]} =
               exit_processor_request
               |> struct!(utxo_exists_result: [false, false, false])
               |> check_validity_filtered(processor, exclude: [Event.PiggybackAvailable])
    end

    test "ifes and standard exits don't interfere, when standard exit is challenged",
         %{alice: alice, processor_empty: processor, transactions: [tx | _]} do
      standard_exit_tx = TestHelper.create_recovered([], @eth, [{alice, 10}])

      {processor, _} =
        processor
        |> start_se_from(standard_exit_tx, @utxo_pos_deposit)
        |> start_ife_from(tx)
        |> Core.challenge_exits([%{utxo_pos: Utxo.Position.encode(@utxo_pos_deposit)}])

      # doesn't check the challenged SE utxo
      assert %{utxos_to_check: [_, Utxo.position(1, 2, 1)]} =
               exit_processor_request =
               %ExitProcessor.Request{eth_timestamp_now: 5 + :os.system_time(:second), blknum_now: @late_blknum}
               |> Core.determine_utxo_existence_to_get(processor)

      # doesn't alert on the challenged SE, despite it being a double-spend wrt the IFE
      assert {:ok, []} =
               exit_processor_request
               |> struct!(utxo_exists_result: [false, false])
               |> check_validity_filtered(processor, exclude: [Event.PiggybackAvailable])
    end

    test "ifes and standard exits don't interfere if all valid",
         %{alice: alice, processor_empty: processor, transactions: [tx | _]} do
      standard_exit_tx = TestHelper.create_recovered([{@deposit_blknum, 0, 0, alice}], @eth, [{alice, 10}])
      processor = processor |> start_se_from(standard_exit_tx, @utxo_pos_tx) |> start_ife_from(tx)

      assert %{utxos_to_check: [_, Utxo.position(1, 2, 1), @utxo_pos_tx]} =
               exit_processor_request =
               %ExitProcessor.Request{eth_timestamp_now: 5 + :os.system_time(:second), blknum_now: @late_blknum}
               |> Core.determine_utxo_existence_to_get(processor)

      assert {:ok, []} =
               exit_processor_request
               |> struct!(utxo_exists_result: [true, true, true])
               |> check_validity_filtered(processor, exclude: [Event.PiggybackAvailable])
    end
  end

  describe "challenge events" do
    test "can challenge exits, which are then forgotten completely",
         %{processor_empty: processor, alice: alice} do
      standard_exit_tx1 = TestHelper.create_recovered([{1, 0, 0, alice}], @eth, [{alice, 10}])
      standard_exit_tx2 = TestHelper.create_recovered([{@blknum2, 0, 1, alice}], @eth, [{alice, 10}, {alice, 10}])

      processor =
        processor
        |> start_se_from(standard_exit_tx1, @utxo_pos_deposit2)
        |> start_se_from(standard_exit_tx2, @utxo_pos_tx2)

      # sanity
      assert %ExitProcessor.Request{utxos_to_check: [_, _]} =
               Core.determine_utxo_existence_to_get(%ExitProcessor.Request{blknum_now: @late_blknum}, processor)

      {processor, _} =
        processor
        |> Core.challenge_exits([@utxo_pos_deposit2, @utxo_pos_tx2] |> Enum.map(&%{utxo_pos: Utxo.Position.encode(&1)}))

      assert %ExitProcessor.Request{utxos_to_check: []} =
               Core.determine_utxo_existence_to_get(%ExitProcessor.Request{blknum_now: @late_blknum}, processor)
    end

    test "can process challenged exits", %{processor_empty: processor, alice: alice} do
      # see the contract and `Eth.RootChain.get_standard_exit_structs/1` for some explanation why like this
      # this is what an exit looks like after a challenge
      zero_status = {false, 0, 0, 0, 0, 0}
      standard_exit_tx = TestHelper.create_recovered([{1, 0, 0, alice}], @eth, [{alice, 10}])
      processor = processor |> start_se_from(standard_exit_tx, @utxo_pos_deposit2, status: zero_status)

      # sanity
      assert %ExitProcessor.Request{utxos_to_check: []} =
               Core.determine_utxo_existence_to_get(%ExitProcessor.Request{blknum_now: @late_blknum}, processor)

      # pinning because challenge shouldn't change the already challenged exit in the processor
      {^processor, _} = processor |> Core.challenge_exits([%{utxo_pos: Utxo.Position.encode(@utxo_pos_deposit2)}])
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

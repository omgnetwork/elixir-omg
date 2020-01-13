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

defmodule OMG.Watcher.ExitProcessor.CanonicityTest do
  @moduledoc """
  Test of the logic of exit processor - detecting conditions related to canonicity game and challenging them:
    - competitors
    - invalid competitors
  """
  use OMG.Watcher.ExitProcessor.Case, async: true

  alias OMG.Block
  alias OMG.State.Transaction
  alias OMG.TestHelper
  alias OMG.Utxo
  alias OMG.Watcher.Event
  alias OMG.Watcher.ExitProcessor
  alias OMG.Watcher.ExitProcessor.Core

  require Utxo

  import OMG.Watcher.ExitProcessor.TestHelper

  @eth OMG.Eth.RootChain.eth_pseudo_address()
  @late_blknum 10_000

  describe "sanity checks" do
    test "can process empty challenges and responses", %{processor_empty: empty, processor_filled: filled} do
      {^empty, []} = Core.new_ife_challenges(empty, [])
      {^filled, []} = Core.new_ife_challenges(filled, [])
      {^empty, []} = Core.respond_to_in_flight_exits_challenges(empty, [])
      {^filled, []} = Core.respond_to_in_flight_exits_challenges(filled, [])
    end
  end

  describe "finds competitors and allows canonicity challenges" do
    test "none if input never spent elsewhere",
         %{processor_filled: processor} do
      assert {:ok, []} =
               %ExitProcessor.Request{blknum_now: 1000, eth_height_now: 5}
               |> check_validity_filtered(processor, exclude: [Event.PiggybackAvailable])
    end

    test "none if different input spent in some tx from appendix",
         %{processor_filled: processor, transactions: [tx1 | _], unrelated_tx: comp} do
      txbytes = txbytes(tx1)
      processor = processor |> start_ife_from(comp)

      assert {:ok, []} =
               %ExitProcessor.Request{blknum_now: 1000, eth_height_now: 5}
               |> check_validity_filtered(processor, exclude: [Event.PiggybackAvailable])

      assert {:error, :competitor_not_found} =
               %ExitProcessor.Request{blknum_now: 5000, eth_height_now: 5}
               |> Core.get_competitor_for_ife(processor, txbytes)
    end

    test "none if different input spent in some tx from block",
         %{processor_filled: processor, transactions: [tx1 | _], unrelated_tx: comp} do
      txbytes = txbytes(tx1)

      exit_processor_request = %ExitProcessor.Request{
        blknum_now: 5000,
        eth_height_now: 5,
        blocks_result: [Block.hashed_txs_at([comp], 3000)]
      }

      assert {:ok, []} =
               exit_processor_request |> check_validity_filtered(processor, exclude: [Event.PiggybackAvailable])

      assert {:error, :competitor_not_found} = exit_processor_request |> Core.get_competitor_for_ife(processor, txbytes)
    end

    test "none if input spent in _same_ tx in block",
         %{processor_filled: processor, transactions: [tx1 | _]} do
      txbytes = txbytes(tx1)

      exit_processor_request = %ExitProcessor.Request{
        blknum_now: 5000,
        eth_height_now: 5,
        blocks_result: [Block.hashed_txs_at([tx1], 3000)]
      }

      assert {:ok, []} =
               exit_processor_request |> check_validity_filtered(processor, exclude: [Event.PiggybackAvailable])

      assert {:error, :competitor_not_found} =
               exit_processor_request
               |> Core.get_competitor_for_ife(processor, txbytes)
    end

    test "none if input spent in _same_ tx in tx appendix",
         %{processor_filled: processor, transactions: [tx | _]} do
      txbytes = txbytes(tx)
      processor = processor |> start_ife_from(tx)

      assert {:ok, []} =
               %ExitProcessor.Request{blknum_now: 5000, eth_height_now: 5}
               |> check_validity_filtered(processor, exclude: [Event.PiggybackAvailable])

      assert {:error, :competitor_not_found} =
               %ExitProcessor.Request{blknum_now: 5000, eth_height_now: 5}
               |> Core.get_competitor_for_ife(processor, txbytes)
    end

    test "each other, if input spent in different ife",
         %{processor_filled: processor, transactions: [tx1 | _], competing_tx: comp} do
      txbytes = txbytes(tx1)
      {comp_txbytes, comp_signature} = {txbytes(comp), sig(comp)}
      processor = processor |> start_ife_from(comp)

      assert {:ok, events} =
               %ExitProcessor.Request{blknum_now: 5000, eth_height_now: 5}
               |> check_validity_filtered(processor, only: [Event.NonCanonicalIFE])

      assert_events(events, [%Event.NonCanonicalIFE{txbytes: txbytes}, %Event.NonCanonicalIFE{txbytes: comp_txbytes}])

      assert {:ok,
              %{
                in_flight_txbytes: ^txbytes,
                in_flight_input_index: 0,
                competing_txbytes: ^comp_txbytes,
                competing_input_index: 1,
                competing_sig: ^comp_signature,
                competing_tx_pos: Utxo.position(0, 0, 0),
                competing_proof: ""
              }} =
               %ExitProcessor.Request{blknum_now: 5000, eth_height_now: 5}
               |> Core.get_competitor_for_ife(processor, txbytes)
    end

    test "a competitor that's submitted as challenge to other IFE",
         %{alice: alice, processor_filled: processor, transactions: [tx1, tx2 | _]} do
      # ifes in processor here aren't competitors to each other, but the challenge filed for tx2 is a competitor
      # for tx1, which is what we want to detect:
      comp = TestHelper.create_recovered([{1, 0, 0, alice}, {2, 1, 0, alice}], [{alice, @eth, 1}])
      {comp_txbytes, comp_signature} = {txbytes(comp), sig(comp)}
      txbytes = Transaction.raw_txbytes(tx1)
      challenge_event = ife_challenge(tx2, comp)
      {processor, _} = Core.new_ife_challenges(processor, [challenge_event])

      exit_processor_request = %ExitProcessor.Request{blknum_now: 5000, eth_height_now: 5}

      assert {:ok, [%Event.NonCanonicalIFE{txbytes: ^txbytes}]} =
               exit_processor_request |> check_validity_filtered(processor, only: [Event.NonCanonicalIFE])

      assert {:ok,
              %{
                in_flight_txbytes: ^txbytes,
                competing_txbytes: ^comp_txbytes,
                competing_input_index: 0,
                competing_sig: ^comp_signature
              }} = exit_processor_request |> Core.get_competitor_for_ife(processor, txbytes)
    end

    test "a single competitor included in a block, with proof",
         %{processor_filled: processor, transactions: [tx1 | _], competing_tx: comp} do
      txbytes = txbytes(tx1)
      {comp_txbytes, comp_signature} = {txbytes(comp), sig(comp)}

      other_blknum = 3000

      exit_processor_request = %ExitProcessor.Request{
        blknum_now: 5000,
        eth_height_now: 5,
        blocks_result: [Block.hashed_txs_at([comp], other_blknum)]
      }

      assert {:ok, [%Event.NonCanonicalIFE{txbytes: ^txbytes}]} =
               exit_processor_request
               |> check_validity_filtered(processor, only: [Event.NonCanonicalIFE])

      assert {:ok,
              %{
                in_flight_txbytes: ^txbytes,
                in_flight_input_index: 0,
                competing_txbytes: ^comp_txbytes,
                competing_input_index: 1,
                competing_sig: ^comp_signature,
                competing_tx_pos: Utxo.position(^other_blknum, 0, 0),
                competing_proof: proof_bytes
              }} =
               exit_processor_request
               |> Core.get_competitor_for_ife(processor, txbytes)

      assert_proof_sound(proof_bytes)
    end

    test "handle two competitors, when the younger one already challenged",
         %{processor_filled: processor, transactions: [tx1 | _], competing_tx: comp} do
      txbytes = txbytes(tx1)
      comp_txbytes = txbytes(comp)
      other_blknum = 3000

      request = %ExitProcessor.Request{
        blknum_now: 5000,
        eth_height_now: 5,
        blocks_result: [Block.hashed_txs_at([comp, comp], other_blknum)],
        ife_input_spending_blocks_result: [Block.hashed_txs_at([comp, comp], other_blknum)]
      }

      # the transaction is firstmost submitted as a competitor, plus we run the preliminary lookup
      processor = processor |> start_ife_from(comp) |> Core.find_ifes_in_blocks(request)

      # after the first, intermediate challenges, there should still be that event active
      assert_intermediate_result = fn processor ->
        assert {:ok, [%Event.NonCanonicalIFE{txbytes: ^txbytes}]} =
                 request |> check_validity_filtered(processor, only: [Event.NonCanonicalIFE])

        # this request always returns the oldest competitor, even if we later use a different one
        assert {:ok, %{competing_txbytes: ^comp_txbytes, competing_tx_pos: Utxo.position(^other_blknum, 0, 0)}} =
                 request |> Core.get_competitor_for_ife(processor, txbytes)
      end

      # sanity check - no challenges yet
      assert_intermediate_result.(processor)

      # now `comp` is used to challenge with no inclusion proof: challenge with IFE (no position, incomplete)
      challenge = ife_challenge(tx1, comp)
      {processor, _} = Core.new_ife_challenges(processor, [challenge])
      assert_intermediate_result.(processor)

      # challenge with the younger competitor (still incomplete challenge)
      young_challenge = ife_challenge(tx1, comp, competitor_position: Utxo.position(other_blknum, 1, 0))
      {processor, _} = Core.new_ife_challenges(processor, [young_challenge])
      assert_intermediate_result.(processor)

      # challenge with the older competitor (complete!)
      older_challenge = ife_challenge(tx1, comp, competitor_position: Utxo.position(other_blknum, 0, 0))
      {processor, _} = Core.new_ife_challenges(processor, [older_challenge])
      # the tx1 IFE got challenged by the oldest competitor now; finally, it's over:
      assert {:ok, []} = request |> check_validity_filtered(processor, only: [Event.NonCanonicalIFE])
      assert {:error, :no_viable_competitor_found} = request |> Core.get_competitor_for_ife(processor, txbytes)
    end

    test "handle two competitors, when both are non canonical and used to challenge",
         %{alice: alice, processor_filled: processor, transactions: [tx1 | _]} do
      comp1 = TestHelper.create_recovered([{1, 0, 0, alice}], [{alice, @eth, 1}])
      comp2 = TestHelper.create_recovered([{1, 0, 0, alice}], [{alice, @eth, 2}])
      txbytes = txbytes(tx1)
      request = %ExitProcessor.Request{blknum_now: 5000, eth_height_now: 5}
      processor = processor |> start_ife_from(comp1) |> start_ife_from(comp2)

      # before any challenge
      assert {:ok, [_, _, _]} = request |> check_validity_filtered(processor, only: [Event.NonCanonicalIFE])

      assert {:ok, %{competing_tx_pos: Utxo.position(0, 0, 0)}} =
               request |> Core.get_competitor_for_ife(processor, txbytes)

      # after challenge - one event less + no need to challenge more
      {processor, _} = Core.new_ife_challenges(processor, [ife_challenge(tx1, comp1)])
      assert {:ok, [_, _]} = request |> check_validity_filtered(processor, only: [Event.NonCanonicalIFE])
      assert {:error, :no_viable_competitor_found} = request |> Core.get_competitor_for_ife(processor, txbytes)
    end

    test "don't show competitors, if IFE tx is included",
         %{processor_filled: processor, transactions: [tx1 | _], competing_tx: comp} do
      txbytes = txbytes(tx1)
      comp_txbytes = txbytes(comp)
      other_blknum = 3000

      request = %ExitProcessor.Request{
        blknum_now: 5000,
        eth_height_now: 5,
        ife_input_spending_blocks_result: [Block.hashed_txs_at([tx1], other_blknum)]
      }

      processor = processor |> start_ife_from(comp) |> Core.find_ifes_in_blocks(request)

      # notice this is `comp` having a competitor reported, not `tx1`
      assert {:ok, [%Event.NonCanonicalIFE{txbytes: ^comp_txbytes}]} =
               request |> check_validity_filtered(processor, only: [Event.NonCanonicalIFE])

      assert {:error, :no_viable_competitor_found} = request |> Core.get_competitor_for_ife(processor, txbytes)
    end

    test "don't show competitors, if IFE tx is included and is the oldest",
         %{processor_filled: processor, transactions: [tx1 | _], competing_tx: comp} do
      txbytes = txbytes(tx1)
      other_blknum = 3000

      request = %ExitProcessor.Request{
        blknum_now: 5000,
        eth_height_now: 5,
        blocks_result: [Block.hashed_txs_at([tx1, comp], other_blknum)],
        ife_input_spending_blocks_result: [Block.hashed_txs_at([tx1, comp], other_blknum)]
      }

      processor = processor |> Core.find_ifes_in_blocks(request)
      # notice this is `comp` having a competitor reported, not `tx1`
      assert {:ok, []} = request |> check_validity_filtered(processor, only: [Event.NonCanonicalIFE])
      assert {:error, :no_viable_competitor_found} = request |> Core.get_competitor_for_ife(processor, txbytes)
    end

    test "show competitors, if IFE tx is included but not the oldest",
         %{processor_filled: processor, transactions: [tx1 | _], competing_tx: comp} do
      txbytes = txbytes(tx1)
      other_blknum = 3000

      request = %ExitProcessor.Request{
        blknum_now: 5000,
        eth_height_now: 5,
        blocks_result: [Block.hashed_txs_at([comp, tx1], other_blknum)],
        ife_input_spending_blocks_result: [Block.hashed_txs_at([comp, tx1], other_blknum)]
      }

      processor = processor |> Core.find_ifes_in_blocks(request)
      # notice this is `comp` having a competitor reported, not `tx1`
      assert {:ok, [%Event.NonCanonicalIFE{txbytes: ^txbytes}]} =
               request |> check_validity_filtered(processor, only: [Event.NonCanonicalIFE])

      assert {:ok, %{}} = request |> Core.get_competitor_for_ife(processor, txbytes)
    end

    test "show competitors, if IFE tx is included but not the oldest - distinct blocks",
         %{processor_filled: processor, transactions: [tx1 | _], competing_tx: comp} do
      txbytes = txbytes(tx1)
      block1 = Block.hashed_txs_at([comp], 3000)
      block2 = Block.hashed_txs_at([tx1], 4000)

      request = %ExitProcessor.Request{
        blknum_now: 5000,
        eth_height_now: 5,
        blocks_result: [block1, block2],
        # note the flipped order here, all still works as the blocks should be processed starting from oldest
        ife_input_spending_blocks_result: [block2, block1]
      }

      processor = processor |> Core.find_ifes_in_blocks(request)
      # notice this is `comp` having a competitor reported, not `tx1`
      assert {:ok, [%Event.NonCanonicalIFE{txbytes: ^txbytes}]} =
               request |> check_validity_filtered(processor, only: [Event.NonCanonicalIFE])

      assert {:ok, %{}} = request |> Core.get_competitor_for_ife(processor, txbytes)
    end

    test "none if IFE is challenged enough already",
         %{processor_filled: processor, transactions: [tx1 | _], competing_tx: comp} do
      txbytes = txbytes(tx1)
      other_blknum = 3000

      request = %ExitProcessor.Request{
        blknum_now: 5000,
        eth_height_now: 5,
        blocks_result: [Block.hashed_txs_at([comp], other_blknum)]
      }

      challenge =
        ife_challenge(tx1, comp, competitor_position: Utxo.position(other_blknum, 0, 0), competing_tx_input_index: 1)

      {processor, _} = Core.new_ife_challenges(processor, [challenge])

      assert {:ok, []} = request |> check_validity_filtered(processor, only: [Event.NonCanonicalIFE])
      assert {:error, :no_viable_competitor_found} = request |> Core.get_competitor_for_ife(processor, txbytes)
    end

    test "a competitor having the double-spend on various input indices",
         %{alice: alice, processor_empty: processor} do
      tx = TestHelper.create_recovered([{1, 0, 0, alice}, {1, 2, 1, alice}], [{alice, @eth, 1}])
      txbytes = txbytes(tx)
      processor = processor |> start_ife_from(tx)

      input_spent_in_idx0 = {1, 0, 0}
      input_spent_in_idx1 = {1, 2, 1}
      other_input1 = {110, 2, 1}
      other_input2 = {111, 2, 1}
      other_input3 = {112, 2, 1}

      comps = [
        Transaction.Payment.new([input_spent_in_idx0], [{alice.addr, @eth, 1}]),
        Transaction.Payment.new([other_input1, input_spent_in_idx0], [{alice.addr, @eth, 1}]),
        Transaction.Payment.new([other_input1, other_input2, input_spent_in_idx0], [{alice.addr, @eth, 1}]),
        Transaction.Payment.new([other_input1, other_input2, other_input3, input_spent_in_idx0], [{alice.addr, @eth, 1}]),
        Transaction.Payment.new([input_spent_in_idx1], [{alice.addr, @eth, 1}]),
        Transaction.Payment.new([other_input1, input_spent_in_idx1], [{alice.addr, @eth, 1}]),
        Transaction.Payment.new([other_input1, other_input2, input_spent_in_idx1], [{alice.addr, @eth, 1}]),
        Transaction.Payment.new([other_input1, other_input2, other_input3, input_spent_in_idx1], [{alice.addr, @eth, 1}])
      ]

      expected_input_ids = [{0, 0}, {1, 0}, {2, 0}, {3, 0}, {0, 1}, {1, 1}, {2, 1}, {3, 1}]

      check = fn {comp, {competing_input_index, in_flight_input_index}} ->
        # unfortunately, transaction validity requires us to duplicate a signature for every non-zero input
        required_priv_key_list =
          comp
          |> Transaction.get_inputs()
          |> Enum.count()
          |> (&List.duplicate(alice.priv, &1)).()

        other_recovered = OMG.TestHelper.sign_recover!(comp, required_priv_key_list)

        exit_processor_request = %ExitProcessor.Request{
          blknum_now: 5000,
          eth_height_now: 5,
          blocks_result: [Block.hashed_txs_at([other_recovered], 3000)]
        }

        assert {:ok, [%Event.NonCanonicalIFE{txbytes: ^txbytes}]} =
                 exit_processor_request |> check_validity_filtered(processor, only: [Event.NonCanonicalIFE])

        assert {:ok,
                %{
                  in_flight_input_index: ^in_flight_input_index,
                  competing_input_index: ^competing_input_index
                }} =
                 exit_processor_request
                 |> Core.get_competitor_for_ife(processor, txbytes)
      end

      comps
      |> Enum.zip(expected_input_ids)
      |> Enum.each(check)
    end

    test "a competitor being signed on various positions",
         %{processor_filled: processor, transactions: [tx1 | _], alice: alice, bob: bob} do
      comp = TestHelper.create_recovered([{10, 2, 1, bob}, {1, 0, 0, alice}], [{alice, @eth, 1}])
      comp_signature = sig(comp, 1)

      exit_processor_request = %ExitProcessor.Request{
        blknum_now: 5000,
        eth_height_now: 5,
        blocks_result: [Block.hashed_txs_at([comp], 3000)]
      }

      assert {:ok, %{competing_sig: ^comp_signature}} =
               exit_processor_request |> Core.get_competitor_for_ife(processor, txbytes(tx1))
    end

    test "a best competitor, included earliest in a block, regardless of conflicting utxo position",
         %{alice: alice, processor_filled: processor, transactions: [tx1 | _], competing_tx: comp} do
      # NOTE that the recent competitor spends an __older__ input. Also note the reversing of block results done below
      #      Regardless of these, the best competitor (from blknum 2000) must always be returned
      # NOTE also that non-included competitors always are considered last, and hence worst and never are returned

      # first the included competitors
      recovered_recent = TestHelper.create_recovered([{1, 0, 0, alice}], [{alice, @eth, 1}])
      recovered_oldest = TestHelper.create_recovered([{1, 0, 0, alice}, {2, 2, 1, alice}], [{alice, @eth, 1}])

      # ife-related competitor
      processor = processor |> start_ife_from(comp)

      exit_processor_request = %ExitProcessor.Request{
        blknum_now: 5000,
        eth_height_now: 5,
        blocks_result: [Block.hashed_txs_at([recovered_oldest], 2000), Block.hashed_txs_at([recovered_recent], 3000)]
      }

      txbytes = txbytes(tx1)

      assert {:ok, %{competing_tx_pos: Utxo.position(2000, 0, 0)}} =
               exit_processor_request
               |> Core.get_competitor_for_ife(processor, txbytes)

      assert {:ok, %{competing_tx_pos: Utxo.position(2000, 0, 0)}} =
               exit_processor_request
               |> Map.update!(:blocks_result, &Enum.reverse/1)
               |> struct!()
               |> Core.get_competitor_for_ife(processor, txbytes)

      # check also that the rule applies to order of txs within a block
      assert {:ok, %{competing_tx_pos: Utxo.position(2000, 0, 0)}} =
               exit_processor_request
               |> Map.put(:blocks_result, [Block.hashed_txs_at([recovered_oldest, recovered_recent], 2000)])
               |> struct!()
               |> Core.get_competitor_for_ife(processor, txbytes)
    end

    test "by asking for utxo existence concerning active ifes and standard exits",
         %{processor_empty: processor, alice: alice} do
      standard_exit_tx = TestHelper.create_recovered([{1000, 0, 0, alice}], @eth, [{alice, 10}, {alice, 10}])
      ife_tx = TestHelper.create_recovered([{1, 0, 0, alice}], @eth, [{alice, 10}])
      standard_exiting_pos = Utxo.position(2_000, 0, 1)
      processor = processor |> start_se_from(standard_exit_tx, standard_exiting_pos) |> start_ife_from(ife_tx)

      assert %{utxos_to_check: [Utxo.position(1, 0, 0), standard_exiting_pos]} =
               %ExitProcessor.Request{blknum_now: @late_blknum}
               |> Core.determine_utxo_existence_to_get(processor)
    end

    test "by asking for utxo spends concerning active ifes",
         %{processor_filled: processor} do
      assert %{spends_to_get: [Utxo.position(1, 2, 1)]} =
               %ExitProcessor.Request{
                 utxos_to_check: [Utxo.position(1, 2, 1), Utxo.position(112, 2, 1)],
                 utxo_exists_result: [false, false]
               }
               |> Core.determine_spends_to_get(processor)
    end

    test "by not asking for utxo spends concerning non-active ifes",
         %{processor_empty: processor, transactions: [tx | _]} do
      processor = processor |> start_ife_from(tx, status: :inactive)

      assert %{utxos_to_check: []} =
               %ExitProcessor.Request{blknum_now: @late_blknum} |> Core.determine_utxo_existence_to_get(processor)
    end

    test "by not asking for utxo existence concerning finalized ifes",
         %{processor_empty: processor, transactions: [tx | _]} do
      tx_hash = Transaction.raw_txhash(tx)
      ife_id = 123

      processor =
        processor
        |> start_ife_from(tx, exit_id: ife_id)
        |> piggyback_ife_from(tx_hash, 1, :input)
        |> piggyback_ife_from(tx_hash, 2, :input)

      finalizations = [
        %{in_flight_exit_id: ife_id, output_index: 1, omg_data: %{piggyback_type: :input}},
        %{in_flight_exit_id: ife_id, output_index: 2, omg_data: %{piggyback_type: :input}}
      ]

      {:ok, processor, _} = Core.finalize_in_flight_exits(processor, finalizations, %{})

      assert %{utxos_to_check: []} =
               %ExitProcessor.Request{blknum_now: @late_blknum} |> Core.determine_utxo_existence_to_get(processor)
    end

    test "returns input txs and input utxo positions for canonicity challenges",
         %{processor_filled: processor, transactions: [tx | _], competing_tx: comp} do
      txbytes = txbytes(tx)
      processor = processor |> start_ife_from(comp)

      request = %ExitProcessor.Request{blknum_now: 1000, eth_height_now: 5}

      assert {:ok, %{input_tx: "input_tx", input_utxo_pos: Utxo.position(1, 0, 0)}} =
               Core.get_competitor_for_ife(request, processor, txbytes)
    end

    test "by not asking for spends on no ifes",
         %{processor_empty: processor} do
      assert %{spends_to_get: []} =
               %ExitProcessor.Request{utxos_to_check: [Utxo.position(1, 0, 0)], utxo_exists_result: [false]}
               |> Core.determine_spends_to_get(processor)
    end

    test "none if input not yet created during sync",
         %{processor_filled: processor} do
      assert %{utxos_to_check: to_check} =
               %ExitProcessor.Request{blknum_now: 1000, eth_height_now: 13}
               |> Core.determine_utxo_existence_to_get(processor)

      assert Utxo.position(9000, 0, 1) not in to_check
    end

    test "for nonexistent tx doesn't crash",
         %{transactions: [tx | _], processor_empty: processor} do
      txbytes = Transaction.raw_txbytes(tx)

      assert {:error, :ife_not_known_for_tx} =
               %ExitProcessor.Request{blknum_now: 5000, eth_height_now: 5}
               |> Core.get_competitor_for_ife(processor, txbytes)
    end

    test "for malformed input txbytes doesn't crash",
         %{processor_empty: processor} do
      assert {:error, :malformed_transaction} =
               %ExitProcessor.Request{blknum_now: 5000, eth_height_now: 5}
               |> Core.get_competitor_for_ife(processor, <<0>>)
    end
  end

  describe "detects the need and allows to respond to canonicity challenges" do
    test "against a competitor",
         %{processor_filled: processor, transactions: [tx1 | _] = txs, competing_tx: comp} do
      {challenged_processor, _} = Core.new_ife_challenges(processor, [ife_challenge(tx1, comp)])
      txbytes = Transaction.raw_txbytes(tx1)
      other_blknum = 3000

      request = %ExitProcessor.Request{
        blknum_now: 5000,
        eth_height_now: 5,
        ife_input_spending_blocks_result: [Block.hashed_txs_at(txs, other_blknum)]
      }

      challenged_processor = challenged_processor |> Core.find_ifes_in_blocks(request)

      assert {:ok, [%Event.InvalidIFEChallenge{txbytes: ^txbytes}]} =
               request |> check_validity_filtered(challenged_processor, only: [Event.InvalidIFEChallenge])

      assert {:ok,
              %{
                in_flight_txbytes: ^txbytes,
                in_flight_tx_pos: Utxo.position(^other_blknum, 0, 0),
                in_flight_proof: proof_bytes
              }} = Core.prove_canonical_for_ife(challenged_processor, txbytes)

      assert_proof_sound(proof_bytes)
    end

    test "proving canonical for nonexistent tx doesn't crash", %{processor_empty: processor, transactions: [tx | _]} do
      txbytes = Transaction.raw_txbytes(tx)
      request = %ExitProcessor.Request{blknum_now: 5000, eth_height_now: 5}
      processor = processor |> Core.find_ifes_in_blocks(request)
      assert {:error, :ife_not_known_for_tx} = Core.prove_canonical_for_ife(processor, txbytes)
    end

    test "for malformed input txbytes doesn't crash", %{processor_empty: processor} do
      request = %ExitProcessor.Request{blknum_now: 5000, eth_height_now: 5}
      processor = processor |> Core.find_ifes_in_blocks(request)
      assert {:error, :malformed_transaction} = Core.prove_canonical_for_ife(processor, <<0>>)
    end

    test "none if ifes are fresh and canonical by default", %{processor_filled: processor} do
      assert {:ok, []} =
               %ExitProcessor.Request{blknum_now: 5000, eth_height_now: 5}
               |> check_validity_filtered(processor, exclude: [Event.PiggybackAvailable])
    end

    test "none if challenge gets responded and ife canonical",
         %{processor_filled: processor, transactions: [tx | _] = txs, competing_tx: comp} do
      txbytes = Transaction.raw_txbytes(tx)
      other_blknum = 3000
      {processor, _} = Core.new_ife_challenges(processor, [ife_challenge(tx, comp)])

      {processor, _} =
        processor
        |> Core.respond_to_in_flight_exits_challenges([ife_response(tx, Utxo.position(other_blknum, 0, 0))])

      request = %ExitProcessor.Request{
        blknum_now: 5000,
        eth_height_now: 5,
        ife_input_spending_blocks_result: [Block.hashed_txs_at(txs, other_blknum)]
      }

      processor = processor |> Core.find_ifes_in_blocks(request)
      assert {:ok, []} = request |> check_validity_filtered(processor, only: [Event.InvalidIFEChallenge])
      assert {:error, :no_viable_canonical_proof_found} = Core.prove_canonical_for_ife(processor, txbytes)
    end

    test "when there are two transaction inclusions to respond with",
         %{processor_filled: processor, transactions: [tx | _], competing_tx: comp} do
      txbytes = Transaction.raw_txbytes(tx)
      other_blknum = 3000
      {processor, _} = Core.new_ife_challenges(processor, [ife_challenge(tx, comp)])

      request = %ExitProcessor.Request{
        blknum_now: 5000,
        eth_height_now: 5,
        # NOTE: `tx` is included twice
        ife_input_spending_blocks_result: [Block.hashed_txs_at([tx, tx], other_blknum)]
      }

      processor = processor |> Core.find_ifes_in_blocks(request)

      assert {:ok, [%Event.InvalidIFEChallenge{txbytes: ^txbytes}]} =
               request |> check_validity_filtered(processor, only: [Event.InvalidIFEChallenge])

      # older is returned but we'll respond with the younger first and then older
      assert {:ok, %{in_flight_tx_pos: Utxo.position(^other_blknum, 0, 0)}} =
               Core.prove_canonical_for_ife(processor, txbytes)

      {processor, _} =
        processor
        |> Core.respond_to_in_flight_exits_challenges([ife_response(tx, Utxo.position(other_blknum, 1, 0))])

      assert {:ok, []} = request |> check_validity_filtered(processor, only: [Event.InvalidIFEChallenge])
      assert {:error, :no_viable_canonical_proof_found} = Core.prove_canonical_for_ife(processor, txbytes)

      {processor, _} =
        processor
        |> Core.respond_to_in_flight_exits_challenges([ife_response(tx, Utxo.position(other_blknum, 0, 0))])

      assert {:ok, []} = request |> check_validity_filtered(processor, only: [Event.InvalidIFEChallenge])
      assert {:error, :no_viable_canonical_proof_found} = Core.prove_canonical_for_ife(processor, txbytes)
    end
  end
end

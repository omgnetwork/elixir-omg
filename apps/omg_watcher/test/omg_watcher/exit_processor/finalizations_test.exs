# Copyright 2019-2020 OMG Network Pte Ltd
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

defmodule OMG.Watcher.ExitProcessor.FinalizationsTest do
  @moduledoc """
  Test of the logic of exit processor - finalizing various flavors of exits and handling finalization validity
  """
  use OMG.Watcher.ExitProcessor.Case, async: true

  alias OMG.Watcher.Block
  alias OMG.Watcher.ExitProcessor
  alias OMG.Watcher.ExitProcessor.Core
  alias OMG.Watcher.State.Transaction
  alias OMG.Watcher.Utxo

  require Utxo

  import OMG.Watcher.ExitProcessor.TestHelper

  @exit_id 1

  describe "sanity checks" do
    test "can process empty finalizations", %{processor_empty: empty, processor_filled: filled} do
      assert {^empty, []} = Core.finalize_exits(empty, {[], []})
      assert {^filled, []} = Core.finalize_exits(filled, {[], []})
      assert {:ok, %{}, []} = Core.prepare_utxo_exits_for_in_flight_exit_finalizations(empty, [])
      assert {:ok, %{}, []} = Core.prepare_utxo_exits_for_in_flight_exit_finalizations(filled, [])
      assert {:ok, ^empty, []} = Core.finalize_in_flight_exits(empty, [], %{})
      assert {:ok, ^filled, []} = Core.finalize_in_flight_exits(filled, [], %{})
    end
  end

  describe "determining utxos that are exited by finalization" do
    test "signals all included txs' outputs as exiting when piggybacked output exits",
         %{processor_empty: processor, transactions: [tx1 | _]} do
      ife_id1 = 1
      tx_hash1 = Transaction.raw_txhash(tx1)
      tx1_blknum = 3000

      # both IFE txs are inlcuded in one of the blocks and picked up by the `ExitProcessor`
      request = %ExitProcessor.Request{
        blknum_now: 5000,
        eth_height_now: 5,
        ife_input_spending_blocks_result: [Block.hashed_txs_at([tx1], tx1_blknum)]
      }

      processor =
        processor
        |> start_ife_from(tx1, exit_id: ife_id1)
        |> piggyback_ife_from(tx_hash1, 0, :input)
        |> piggyback_ife_from(tx_hash1, 1, :input)
        |> piggyback_ife_from(tx_hash1, 0, :output)
        |> piggyback_ife_from(tx_hash1, 1, :output)
        |> Core.find_ifes_in_blocks(request)

      finalizations = [
        %{in_flight_exit_id: ife_id1, output_index: 0, omg_data: %{piggyback_type: :output}},
        %{in_flight_exit_id: ife_id1, output_index: 1, omg_data: %{piggyback_type: :output}}
      ]

      ife_id1 = <<ife_id1::192>>

      tx1_first_output = Utxo.position(tx1_blknum, 0, 0)
      tx1_second_output = Utxo.position(tx1_blknum, 0, 1)

      assert {
               :ok,
               %{^ife_id1 => [^tx1_first_output, ^tx1_second_output]},
               [{%{output_index: 0}, [^tx1_first_output]}, {%{output_index: 1}, [^tx1_second_output]}]
             } = Core.prepare_utxo_exits_for_in_flight_exit_finalizations(processor, finalizations)
    end

    test "doesn't signal non-included txs' outputs as exiting when piggybacked output exits",
         %{processor_empty: processor, transactions: [tx1 | _]} do
      ife_id1 = 2
      tx_hash1 = Transaction.raw_txhash(tx1)

      request = %ExitProcessor.Request{
        blknum_now: 5000,
        eth_height_now: 5,
        ife_input_spending_blocks_result: []
      }

      processor =
        processor
        |> start_ife_from(tx1, exit_id: ife_id1)
        |> piggyback_ife_from(tx_hash1, 0, :output)
        |> piggyback_ife_from(tx_hash1, 1, :output)
        |> Core.find_ifes_in_blocks(request)

      finalizations = [
        %{in_flight_exit_id: ife_id1, output_index: 0, omg_data: %{piggyback_type: :output}},
        %{in_flight_exit_id: ife_id1, output_index: 1, omg_data: %{piggyback_type: :output}}
      ]

      ife_id1 = <<ife_id1::192>>

      assert {:ok, %{^ife_id1 => []}, []} =
               Core.prepare_utxo_exits_for_in_flight_exit_finalizations(processor, finalizations)
    end

    test "returns utxos that should be spent when exit finalizes, two ifes combined",
         %{processor_empty: processor, transactions: [tx1, tx2 | _]} do
      ife_id1 = 1
      ife_id2 = 2
      tx_hash1 = Transaction.raw_txhash(tx1)
      tx_hash2 = Transaction.raw_txhash(tx2)
      tx2_blknum = 3000

      # both IFE txs are inlcuded in one of the blocks and picked up by the `ExitProcessor`
      request = %ExitProcessor.Request{
        blknum_now: 5000,
        eth_height_now: 5,
        ife_input_spending_blocks_result: [Block.hashed_txs_at([tx1, tx2], tx2_blknum)]
      }

      processor =
        processor
        |> start_ife_from(tx1, exit_id: ife_id1)
        |> start_ife_from(tx2, exit_id: ife_id2)
        |> Core.find_ifes_in_blocks(request)
        |> piggyback_ife_from(tx_hash1, 0, :input)
        |> piggyback_ife_from(tx_hash1, 1, :input)
        |> piggyback_ife_from(tx_hash2, 0, :output)
        |> piggyback_ife_from(tx_hash2, 1, :output)

      finalizations = [
        %{in_flight_exit_id: ife_id1, output_index: 0, omg_data: %{piggyback_type: :input}},
        %{in_flight_exit_id: ife_id2, output_index: 0, omg_data: %{piggyback_type: :output}}
      ]

      assert {:ok, %{}, []} = Core.prepare_utxo_exits_for_in_flight_exit_finalizations(processor, [])

      ife_id1 = <<ife_id1::192>>
      ife_id2 = <<ife_id2::192>>

      tx1_first_input = tx1 |> Transaction.get_inputs() |> hd()
      tx2_first_output = Utxo.position(tx2_blknum, 1, 0)

      assert {
               :ok,
               %{^ife_id1 => [^tx1_first_input], ^ife_id2 => [^tx2_first_output]},
               [
                 {%{in_flight_exit_id: ^ife_id1}, [^tx1_first_input]},
                 {%{in_flight_exit_id: ^ife_id2}, [^tx2_first_output]}
               ]
             } = Core.prepare_utxo_exits_for_in_flight_exit_finalizations(processor, finalizations)
    end

    test "fails when unknown in-flight exit is being finalized", %{processor_empty: processor} do
      finalization = %{in_flight_exit_id: @exit_id, output_index: 1, omg_data: %{piggyback_type: :input}}

      {:unknown_in_flight_exit, unknown_exits} =
        Core.prepare_utxo_exits_for_in_flight_exit_finalizations(processor, [finalization])

      assert unknown_exits == MapSet.new([<<@exit_id::192>>])
    end

    test "fails when exiting an output that is not piggybacked",
         %{processor_empty: processor, transactions: [tx | _]} do
      tx_hash = Transaction.raw_txhash(tx)
      ife_id = 123

      processor =
        processor
        |> start_ife_from(tx, exit_id: ife_id)
        |> piggyback_ife_from(tx_hash, 1, :input)

      finalization1 = %{in_flight_exit_id: ife_id, output_index: 1, omg_data: %{piggyback_type: :input}}
      finalization2 = %{in_flight_exit_id: ife_id, output_index: 2, omg_data: %{piggyback_type: :input}}

      expected_unknown_piggybacks = [
        %{in_flight_exit_id: <<ife_id::192>>, output_index: 2, omg_data: %{piggyback_type: :input}}
      ]

      {:inactive_piggybacks_finalizing, ^expected_unknown_piggybacks} =
        Core.prepare_utxo_exits_for_in_flight_exit_finalizations(processor, [finalization1, finalization2])
    end
  end

  describe "in-flight exit finalization" do
    test "exits piggybacked transaction inputs",
         %{processor_empty: processor, transactions: [tx | _]} do
      ife_id = 123
      tx_hash = Transaction.raw_txhash(tx)

      processor =
        processor
        |> start_ife_from(tx, exit_id: ife_id)
        |> piggyback_ife_from(tx_hash, 0, :input)
        |> piggyback_ife_from(tx_hash, 1, :input)

      assert {:ok, processor, [{:put, :in_flight_exit_info, _}]} =
               Core.finalize_in_flight_exits(
                 processor,
                 [%{in_flight_exit_id: ife_id, output_index: 0, omg_data: %{piggyback_type: :input}}],
                 %{}
               )

      assert {:ok, _, [{:put, :in_flight_exit_info, _}]} =
               Core.finalize_in_flight_exits(
                 processor,
                 [%{in_flight_exit_id: ife_id, output_index: 1, omg_data: %{piggyback_type: :input}}],
                 %{}
               )
    end

    test "exits piggybacked transaction outputs",
         %{processor_empty: processor, transactions: [tx | _]} do
      ife_id = 123
      tx_hash = Transaction.raw_txhash(tx)

      processor =
        processor
        |> start_ife_from(tx, exit_id: ife_id)
        |> piggyback_ife_from(tx_hash, 0, :output)
        |> piggyback_ife_from(tx_hash, 1, :output)

      assert {:ok, _, [{:put, :in_flight_exit_info, _}]} =
               Core.finalize_in_flight_exits(
                 processor,
                 [
                   %{in_flight_exit_id: ife_id, output_index: 1, omg_data: %{piggyback_type: :output}},
                   %{in_flight_exit_id: ife_id, output_index: 0, omg_data: %{piggyback_type: :output}}
                 ],
                 %{}
               )
    end

    test "deactivates in-flight exit after all piggybacked outputs are finalized",
         %{processor_empty: processor, transactions: [tx | _]} do
      ife_id = 123
      tx_hash = Transaction.raw_txhash(tx)

      processor =
        processor
        |> start_ife_from(tx, exit_id: ife_id)
        |> piggyback_ife_from(tx_hash, 1, :input)
        |> piggyback_ife_from(tx_hash, 2, :input)

      {:ok, processor, _} =
        Core.finalize_in_flight_exits(
          processor,
          [%{in_flight_exit_id: ife_id, output_index: 1, omg_data: %{piggyback_type: :input}}],
          %{}
        )

      [_] = Core.get_active_in_flight_exits(processor)

      {:ok, processor, _} =
        Core.finalize_in_flight_exits(
          processor,
          [%{in_flight_exit_id: ife_id, output_index: 2, omg_data: %{piggyback_type: :input}}],
          %{}
        )

      assert [] == Core.get_active_in_flight_exits(processor)
    end

    test "finalizing multiple times returns an error since it is not possible",
         %{processor_empty: processor, transactions: [tx | _]} do
      ife_id = 123
      tx_hash = Transaction.raw_txhash(tx)

      processor =
        processor
        |> start_ife_from(tx, exit_id: ife_id)
        |> piggyback_ife_from(tx_hash, 1, :input)

      finalization = %{in_flight_exit_id: ife_id, output_index: 1, omg_data: %{piggyback_type: :input}}
      {:ok, processor, _} = Core.finalize_in_flight_exits(processor, [finalization], %{})
      {:inactive_piggybacks_finalizing, _} = Core.finalize_in_flight_exits(processor, [finalization], %{})
    end

    test "finalizing perserve in flights exits that are not being finalized",
         %{processor_empty: processor, transactions: [tx1, tx2]} do
      ife_id1 = 123
      tx_hash1 = Transaction.raw_txhash(tx1)
      ife_id2 = 124
      tx_hash2 = Transaction.raw_txhash(tx2)

      processor =
        processor
        |> start_ife_from(tx1, exit_id: ife_id1)
        |> start_ife_from(tx2, exit_id: ife_id2)
        |> piggyback_ife_from(tx_hash1, 1, :input)

      finalization = %{in_flight_exit_id: ife_id1, output_index: 1, omg_data: %{piggyback_type: :input}}
      {:ok, processor, _} = Core.finalize_in_flight_exits(processor, [finalization], %{})
      [%{txhash: ^tx_hash2}] = Core.get_active_in_flight_exits(processor)
    end

    test "fails when unknown in-flight exit is being finalized", %{processor_empty: processor} do
      finalization = %{in_flight_exit_id: @exit_id, output_index: 1, omg_data: %{piggyback_type: :input}}

      {:unknown_in_flight_exit, unknown_exits} = Core.finalize_in_flight_exits(processor, [finalization], %{})
      assert unknown_exits == MapSet.new([<<@exit_id::192>>])
    end

    test "fails when exiting an output that is not piggybacked",
         %{processor_empty: processor, transactions: [tx | _]} do
      tx_hash = Transaction.raw_txhash(tx)
      ife_id = 123

      processor =
        processor
        |> start_ife_from(tx, exit_id: ife_id)
        |> piggyback_ife_from(tx_hash, 1, :input)

      finalization1 = %{in_flight_exit_id: ife_id, output_index: 1, omg_data: %{piggyback_type: :input}}
      finalization2 = %{in_flight_exit_id: ife_id, output_index: 2, omg_data: %{piggyback_type: :input}}

      expected_unknown_piggybacks = [
        %{in_flight_exit_id: <<ife_id::192>>, output_index: 2, omg_data: %{piggyback_type: :input}}
      ]

      {:inactive_piggybacks_finalizing, ^expected_unknown_piggybacks} =
        Core.finalize_in_flight_exits(processor, [finalization1, finalization2], %{})
    end
  end
end

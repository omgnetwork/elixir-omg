# Copyright 2019 OmiseGO Pte Ltd
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

defmodule OMG.Watcher.ExitProcessor.Case do
  @moduledoc """
  `ExUnit` test case for a shared setup used in `ExitProcessor.Core` logic tests
  """
  use ExUnit.CaseTemplate

  alias OMG.Block
  alias OMG.State.Transaction
  alias OMG.TestHelper
  alias OMG.Utxo
  alias OMG.Watcher.ExitProcessor
  alias OMG.Watcher.ExitProcessor.Core

  require Utxo

  import OMG.Watcher.ExitProcessor.TestHelper

  @eth OMG.Eth.RootChain.eth_pseudo_address()
  @not_eth <<1::size(160)>>

  setup do
    [alice, bob, carol] = 1..3 |> Enum.map(fn _ -> TestHelper.generate_entity() end)

    transactions = [
      TestHelper.create_recovered([{1, 0, 0, alice}, {1, 2, 1, carol}], [{alice, @eth, 1}, {carol, @eth, 2}]),
      TestHelper.create_recovered([{2, 1, 0, alice}, {2, 2, 1, carol}], [{alice, @not_eth, 1}, {carol, @not_eth, 2}])
    ]

    competing_tx =
      TestHelper.create_recovered([{10, 2, 1, alice}, {1, 0, 0, alice}], [{bob, @eth, 2}, {carol, @eth, 1}])

    unrelated_tx =
      TestHelper.create_recovered([{20, 1, 0, alice}, {20, 20, 1, alice}], [{bob, @eth, 2}, {carol, @eth, 1}])

    {:ok, processor_empty} = Core.init([], [], [])

    in_flight_exit_events =
      transactions |> Enum.zip([2, 4]) |> Enum.map(fn {tx, eth_height} -> ife_event(tx, eth_height: eth_height) end)

    ife_tx_hashes = transactions |> Enum.map(&Transaction.raw_txhash/1)

    processor_filled =
      transactions
      |> Enum.zip([1, 4])
      |> Enum.reduce(processor_empty, fn {tx, idx}, processor ->
        # use the idx as both two distinct ethereum heights and two distinct exit_ids arriving from the root chain
        start_ife_from(processor, tx, eth_height: idx, exit_id: idx)
      end)

    {:ok,
     %{
       alice: alice,
       bob: bob,
       carol: carol,
       transactions: transactions,
       competing_tx: competing_tx,
       unrelated_tx: unrelated_tx,
       processor_empty: processor_empty,
       in_flight_exit_events: in_flight_exit_events,
       ife_tx_hashes: ife_tx_hashes,
       processor_filled: processor_filled,
       invalid_piggyback_on_input:
         invalid_piggyback_on_input(processor_filled, transactions, ife_tx_hashes, competing_tx),
       invalid_piggyback_on_output: invalid_piggyback_on_output(alice, processor_filled, transactions, ife_tx_hashes)
     }}
  end

  defp invalid_piggyback_on_input(state, [tx | _], [ife_id | _], competing_tx) do
    request = %ExitProcessor.Request{
      blknum_now: 4000,
      eth_height_now: 5,
      ife_input_spending_blocks_result: [Block.hashed_txs_at([tx], 3000)]
    }

    state =
      state
      |> start_ife_from(competing_tx)
      |> piggyback_ife_from(ife_id, 0, :input)
      |> Core.find_ifes_in_blocks(request)

    %{
      state: state,
      request: request,
      ife_input_index: 0,
      ife_txbytes: txbytes(tx),
      spending_txbytes: txbytes(competing_tx),
      spending_input_index: 1,
      spending_sig: sig(competing_tx)
    }
  end

  defp invalid_piggyback_on_output(alice, state, [tx | _], [ife_id | _]) do
    # the piggybacked-output-spending tx is going to be included in a block, which requires more back&forth
    # 1. transaction which is, ife'd, output piggybacked, and included in a block
    # 2. transaction which spends that piggybacked output
    comp = TestHelper.create_recovered([{3000, 0, 0, alice}], [])

    tx_blknum = 3000
    comp_blknum = 4000
    block = Block.hashed_txs_at([tx], tx_blknum)

    request = %ExitProcessor.Request{
      blknum_now: 5000,
      eth_height_now: 5,
      blocks_result: [block],
      ife_input_spending_blocks_result: [block, Block.hashed_txs_at([comp], comp_blknum)]
    }

    # 3. stuff happens in the contract; output #4 is a double-spend; #5 is OK
    state =
      state
      |> piggyback_ife_from(ife_id, 0, :output)
      |> piggyback_ife_from(ife_id, 1, :output)
      |> Core.find_ifes_in_blocks(request)

    %{
      state: state,
      request: request,
      ife_good_pb_index: 5,
      ife_txbytes: txbytes(tx),
      ife_output_pos: Utxo.position(tx_blknum, 0, 0),
      ife_proof: Block.inclusion_proof(block, 0),
      spending_txbytes: txbytes(comp),
      spending_input_index: 0,
      spending_sig: sig(comp),
      ife_input_index: 4
    }
  end
end

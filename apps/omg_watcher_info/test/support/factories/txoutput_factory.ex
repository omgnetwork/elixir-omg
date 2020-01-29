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

defmodule OMG.WatcherInfo.Factory.TxOutput do
  @moduledoc """
    TxOutput factory.

    Generates a txoutput with a `blknum` using blknum sequence from the block factory.the 1, 1001,
    2001, etc... In most test use cases `blknum` should be overridden.

    If you are overriding some values, also consider its relation to other values. E.g:

      - To override `blknum`, also consider overriding `txindex`.
      - To override `creating_transaction`, also consider overriding `txindex` and `oindex`.
      - To override `spending_transaction`, also consider overriding `spending_tx_oindex`
  """
  defmacro __using__(_opts) do
    quote do
      alias OMG.Utxo
      alias OMG.WatcherInfo.DB

      require Utxo

      @eth OMG.Eth.RootChain.eth_pseudo_address()

      def txoutput_factory(attrs \\ %{}) do
        # use the blknum sequence for block.blknum
        {blknum, attrs} =
          case attrs[:blknum] do
            nil ->
              {sequence(:block_blknum, fn seq -> seq * 1000 + 1 end), attrs}

            blknum ->
              {blknum, Map.delete(attrs, :blknum)}
          end

        txoutput = %DB.TxOutput{
          blknum: blknum,
          txindex: 0,
          oindex: 0,
          owner: insecure_random_bytes(20),
          amount: 100,
          currency: @eth,
          creating_transaction: nil,
          spending_transaction: nil,
          spending_tx_oindex: nil,
          proof: insecure_random_bytes(32),
          ethevents: []
        }

        txoutput = merge_attributes(txoutput, attrs)

        child_chain_utxohash =
          DB.TxOutput.generate_child_chain_utxohash(Utxo.position(txoutput.blknum, txoutput.txindex, txoutput.oindex))

        Map.put(txoutput, :child_chain_utxohash, child_chain_utxohash)
      end

      def deposit_factory(attrs \\ %{}) do
        {blknum, attrs} =
          case attrs[:blknum] do
            nil ->
              {sequence(:block_blknum, fn seq -> seq * 1000 + 1 end), attrs}

            blknum ->
              {blknum, Map.delete(attrs, :blknum)}
          end

        %DB.EthEvent{
          root_chain_txhash: insecure_random_bytes(32),
          # within a log there may be 0 or more ethereum events, this is the index of the
          # event within the log
          log_index: 0,
          event_type: :deposit,
          txoutputs: []
        }
      end

#       remove with_deposit and with_standard_exit....call deposit_factory instead as this will influence the blknum sequencing.
#       see this query:
#       select t.blknum from txoutputs t, ethevents_txoutputs et, ethevents e where t.child_chain_utxohash=et.child_chain_utxohash and et.root_chain_txhash_event = e.root_chain_txhash_event and e.event_type='deposit';
#  blknum 
# --------
#       1
#    1001
#    1002
#    2001
#   11001
#   12001
#   24001
#   25001
#   25002
#   25003
#   25004
#   25005
#   25006

      def standard_exit_factory() do
        
      end

      def with_deposit(txoutput) do
        ethevent = build(:ethevent)
        Map.put(txoutput, :ethevents, [ethevent] ++ txoutput.ethevents)
      end

      def with_standard_exit(txoutput) do
        ethevent = build(:ethevent, event_type: :standard_exit)
        Map.put(txoutput, :ethevents, [ethevent] ++ txoutput.ethevents)
      end

      # if testing with a transaction containing multiple txoutput outputs then consider using the transaction
      # factory's `with_outputs()` function instead
      def with_creating_transaction(txoutput, transaction \\ nil) do
        transaction =
          case transaction do
            nil -> build(:transaction)
            transaction -> transaction
          end

        txoutput =
          struct(txoutput, %{
            blknum: transaction.block.blknum,
            creating_txhash: transaction.txhash,
            txindex: length(transaction.outputs)
          })

        Map.put(
          txoutput,
          :child_chain_utxohash,
          DB.TxOutput.generate_child_chain_utxohash(Utxo.position(txoutput.blknum, txoutput.txindex, txoutput.oindex))
        )
      end

      # if testing with a transaction containing multiple txoutput inputs then consider using the transaction
      # factory's `with_inputs()` function instead
      def with_spending_transaction(txoutput, transaction \\ nil) do
        transaction =
          case transaction do
            nil -> build(:transaction)
            transaction -> transaction
          end

        txoutput
        |> Map.put(:proof, insecure_random_bytes(32))
        |> Map.put(:spending_transaction, transaction)
        |> Map.put(:spending_tx_oindex, length(transaction.inputs))
      end
    end
  end
end

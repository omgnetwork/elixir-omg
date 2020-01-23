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

defmodule OMG.WatcherInfo.Factory.Transaction do
  @moduledoc """
    Transaction factory.

    Generates a transaction without any transaction inputs or outputs.

    To generate a transaction with closest data to production, consider generating transaction inputs and/or outputs
    and associate them with this transaction.
  """
  defmacro __using__(_opts) do
    quote do
      alias OMG.WatcherInfo.DB

      alias OMG.Utxo
      require Utxo

      def transaction_factory(attrs \\ %{}) do
        {block, attrs} = case attrs[:block] do
          nil -> {build(:block, tx_count: 1), attrs}

          block ->
            block = Map.put(block, :tx_count, Map.get(block, :tx_count) + 1)

            {block, Map.delete(attrs, :block)}
          end

        transaction = %DB.Transaction{
          txhash: insecure_random_bytes(32),
          txindex: block.tx_count - 1,
          txbytes: insecure_random_bytes(32),
          metadata: insecure_random_bytes(32),
          block: block,
          inputs: [],
          outputs: []
        }

        # not returning `merge_attributes(transaction, attrs)` to avoid dialyzer errors
        transaction = merge_attributes(transaction, attrs)
        transaction
      end

      def with_inputs(transaction, txoutputs) do
        {_, transaction} =
          txoutputs
          |> Enum.with_index()
          |> Enum.map_reduce(transaction, fn {txoutput, index}, transaction ->
               input_fields = %{
                 proof: insecure_random_bytes(32),
                 spending_transaction: transaction,
                 spending_tx_oindex: index
               }
               
               utxo_pos = Utxo.position(txoutput.blknum, txoutput.txindex, txoutput.oindex)

               txoutput = DB.TxOutput.get_by_position(utxo_pos) || txoutput

               {:ok, txoutput} =
                 txoutput
                 |> Ecto.Changeset.change(input_fields)
                 |> DB.Repo.insert_or_update()

               {{txoutput, index}, Map.put(transaction, :inputs, transaction.inputs ++ [txoutput])}
             end)

        transaction
      end

      def with_outputs(transaction, txoutputs) do
        {_, transaction} =
          txoutputs
          |> Enum.with_index()
          |> Enum.map_reduce(transaction, fn {txoutput, index}, transaction ->
               output_fields = %{
                 creating_transaction: transaction,
                 blknum: transaction.block.blknum,
                 txindex: transaction.txindex,
                 oindex: index
               }

               child_chain_utxohash =
                 DB.TxOutput.generate_child_chain_utxohash(
                   Utxo.position(txoutput.blknum, txoutput.txindex, txoutput.oindex))

               output_fields = Map.put(output_fields, :child_chain_utxohash, child_chain_utxohash)

               txoutput = insert(struct(txoutput, output_fields))

               {{txoutput, index}, Map.put(transaction, :outputs, transaction.outputs ++ [txoutput])}
             end)

        transaction
      end
    end
  end
end

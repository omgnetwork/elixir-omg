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
      require OMG.Utxo

      def transaction_factory(attrs \\ %{}) do
        block = attrs[:block] || build(:block)

        tx_count =
          case block.tx_count do
            nil -> 1
            tx_count -> tx_count
          end

        block = Map.put(block, :tx_count, tx_count)

        transaction = %DB.Transaction{
          txhash: insecure_random_bytes(32),
          txindex: length(block.transactions),
          txbytes: insecure_random_bytes(32),
          metadata: insecure_random_bytes(32),
          block: block,
          inputs: [],
          outputs: []
        }

        transaction = merge_attributes(transaction, attrs)
        transaction
      end

      def with_inputs(transaction, txoutputs) do
        {_, transaction} =
          txoutputs
          |> Enum.with_index()
          |> Enum.map_reduce(transaction, fn {txoutput, index}, transaction ->
            txoutput =
              txoutput
              |> Map.put(:proof, insecure_random_bytes(32))
              |> Map.put(:spending_txhash, transaction.txhash)
              |> Map.put(:spending_tx_oindex, index)

            {{txoutput, index}, Map.put(transaction, :inputs, Enum.concat(transaction.inputs, [txoutput]))}
          end)

        transaction
      end

      def with_outputs(transaction, txoutputs) do
        {_, transaction} =
          txoutputs
          |> Enum.with_index()
          |> Enum.map_reduce(transaction, fn {txoutput, index}, transaction ->
            txoutput =
              txoutput
              |> Map.put(:blknum, transaction.block.blknum)
              |> Map.put(:txindex, index)

            {{txoutput, index}, Map.put(transaction, :outputs, Enum.concat(transaction.outputs, [txoutput]))}
          end)

        transaction
      end

      # when inputs are added to a transaction some of the inputs' attributes are changed.
      # transaction inputs are usually already inserted in the database as outputs of an
      # earlier transaction. because the transaction inputs are already in the db, and ExMachina
      # only support inserts, this function is needed to update the inputs.
      #
      # note that the transaction must be insert first so that when the inputs are updated with
      # input.txhash = transaction.txhash it does not violate a FK constraint. this function is needed
      def update_inputs_as_spent(transaction) do
        :ok =
          Enum.each(transaction.inputs, fn input ->
            {:ok, txoutput} =
              input
              |> Ecto.Changeset.change()
              |> Ecto.Changeset.force_change(:proof, input.proof)
              |> Ecto.Changeset.force_change(:spending_txhash, input.spending_txhash)
              |> Ecto.Changeset.force_change(:spending_tx_oindex, input.spending_tx_oindex)
              |> DB.Repo.update()

            :ok
          end)

        # return transaction with up-to-date data
        DB.Transaction.get(transaction.txhash)
      end
    end
  end
end

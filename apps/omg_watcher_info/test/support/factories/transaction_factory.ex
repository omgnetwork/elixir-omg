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
  defmacro __using__(_opts) do
    quote do
      alias OMG.WatcherInfo.DB

      alias OMG.Utxo
      require OMG.Utxo

      # @doc """
      # Transaction factory.

      # Generates a transaction without any transaction inputs or outputs.

      # To generate a transaction with closest data to production, consider generating transaction inputs and/or outputs
      # and associate them with this transaction.
      # """
      def transaction_factory(attrs \\ %{}) do
        block = attrs[:block] || build(:block)

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
          Enum.map_reduce(txoutputs, transaction, fn txoutput, transaction ->
            txoutput =
              txoutput
              |> Map.put(:proof, insecure_random_bytes(32))
              |> Map.put(:spending_txhash, transaction.txhash)
              |> Map.put(:spending_tx_oindex, length(transaction.inputs))

            {txoutput, Map.put(transaction, :inputs, Enum.concat(transaction.inputs, [txoutput]))}
          end)

        transaction
      end

      def with_outputs(transaction, txoutputs) do
        {_, transaction} =
          Enum.map_reduce(txoutputs, transaction, fn txoutput, transaction ->
            txoutput =
              txoutput
              |> Map.put(:blknum, transaction.block.blknum)
              |> Map.put(:txindex, length(transaction.outputs))

            {txoutput, Map.put(transaction, :outputs, Enum.concat(transaction.outputs, [txoutput]))}
          end)

        transaction
      end

      # this is needed because ExMachina only supports inserting data, not updating it. transaction
      # inputs that have been spent are updated here with info from the transaction it was spent in
      def update_inputs_as_spent(transaction) do
        {_, transaction} =
          Enum.map_reduce(transaction.inputs, transaction, fn input, transaction ->
            txoutput =
              case DB.TxOutput.get_by_position(Utxo.position(input.blknum, input.txindex, input.oindex)) do
                nil ->
                  input

                txoutput ->
                  {:ok, txoutput} =
                    txoutput
                    |> Ecto.Changeset.change(%{
                      proof: input.proof,
                      spending_txhash: input.spending_txhash,
                      spending_tx_oindex: input.spending_tx_oindex
                    })
                    |> DB.Repo.update()

                  txoutput
              end

            {txoutput, transaction}
          end)

        transaction
      end
    end
  end
end

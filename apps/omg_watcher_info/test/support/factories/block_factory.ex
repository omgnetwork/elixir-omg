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

defmodule OMG.WatcherInfo.Factory.Block do
  @moduledoc """
    Block factory.

    Generates a block in an incremental blknum of 1, 1001, 2001, 3001, etc with
    no associations to any other objects.

    Note that `tx_count` is an aggregate sum(block.transactinons) field and does
    not automatically get setup in the tests. In most cases `tx_count` will 
    need to be managed manually.
  """
  defmacro __using__(_opts) do
    quote do
      alias OMG.WatcherInfo.DB

      def block_factory() do
        %DB.Block{
          blknum: sequence(:block_blknum, fn seq -> seq * 1000 + 1 end),
          hash: insecure_random_bytes(32),
          eth_height: sequence(:block_eth_height, fn seq -> seq end),
          timestamp: sequence(:block_timestamp, fn seq -> seq end),
          transactions: [],
          tx_count: 0
        }
      end

      def with_transactions(block, transactions) do
        transactions =
          transactions
          |> Enum.with_index()
          |> Enum.map(fn {transaction, txindex} ->
            transaction =
              Map.put(transaction, :block, block)
              |> Map.put(:txindex, txindex)
              |> insert()

            IO.inspect(transaction, label: "transaction in with_transactions")

            #  |> Map.put(:inputs, inputs)
            #  |> Map.put(:outputs, outputs)

            # insert(transaction)
            #   inputs = 
            #     transaction.inputs
            #     |> Enum.with_index()
            #     |> Enum.map(fn {input, spending_tx_oindex} -> 
            #          Map.put(input, :spending_tx_oindex, spending_tx_oindex)
            #          |> Map.put(:spending_transaction, transaction)
            #          |> Map.put(:proof, insecure_random_bytes(32))
            #        end) 

            #   outputs =
            #     transaction.outputs
            #     |> Enum.with_index()
            #     |> Enum.map(fn {output, oindex} -> 
            #          Map.put(output, :blknum, block.blknum)
            #          |> Map.put(:txindex, txindex)
            #          |> Map.put(:oindex, oindex)
            #          |> Map.put(:creating_transaction, transaction)
            #     end) 
          end)

        Map.put(block, :transactions, transactions)
        |> Map.put(:tx_count, length(transactions))
      end
    end
  end
end

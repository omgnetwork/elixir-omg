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

defmodule OMG.WatcherInfo.Factory.Block do
  @moduledoc """
    Block factory.

    Generates an empty test block with no transactions.

    Two ways to generate a block with transactions are:
      1. Build a transaction first:
            ```
              build(:transaction)
            ```
         which will automatically create a block that the transaction belongs to.

      2. Build an empty block and then build a transaction passing in the empty
         block to the transaction factory:
            ```
              block = build(:block)
              transaction = build(:transaction, block: block)

            ```

    Note that `tx_count` is an aggregate sum(block.transactions) field and does
    not automatically get setup in the tests. In most cases `tx_count` will
    need to be managed manually.
  """
  defmacro __using__(_opts) do
    quote do
      alias OMG.WatcherInfo.DB

      def block_factory() do
        block = %DB.Block{
          blknum: sequence(:block_blknum, fn seq -> seq * 1000 end),
          hash: insecure_random_bytes(32),
          eth_height: sequence(:block_eth_height, fn seq -> seq end),
          timestamp: sequence(:block_timestamp, fn seq -> seq end),
          transactions: [],
          tx_count: 0
        }
      end
    end
  end
end

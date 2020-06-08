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

defmodule OMG.WatcherInfo.Factory.PendingBlock do
  @moduledoc """
    Pending Block factory.

    Generates a pending block that will need to be processed and inserted to the database.
  """

  defmacro __using__(_opts) do
    quote do
      alias OMG.TestHelper
      alias OMG.WatcherInfo.DB

      @eth OMG.Eth.zero_address()

      def pending_block_factory() do
        blknum = sequence(:block_blknum, fn seq -> (seq + 1) * 1000 end)
        alice = TestHelper.generate_entity()
        bob = TestHelper.generate_entity()

        tx_1 = TestHelper.create_recovered([{blknum + 1, 0, 0, alice}], @eth, [{bob, 300}])
        tx_2 = TestHelper.create_recovered([{blknum + 1, 0, 0, alice}], @eth, [{bob, 500}])

        block = %DB.PendingBlock{
          data:
            :erlang.term_to_binary(%{
              blknum: blknum,
              blkhash: insecure_random_bytes(32),
              eth_height: sequence(:block_eth_height, fn seq -> seq + 1 end),
              timestamp: sequence(:block_timestamp, fn seq -> seq + 1 end),
              transactions: [tx_1, tx_2],
              tx_count: 2
            }),
          blknum: blknum,
          status: DB.PendingBlock.status_pending()
        }
      end
    end
  end
end

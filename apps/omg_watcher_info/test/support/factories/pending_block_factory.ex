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
      alias OMG.WatcherInfo.DB

      def pending_block_factory() do
        blknum = sequence(:block_blknum, fn seq -> seq * 1000 end)

        block = %DB.PendingBlock{
          data:
            :erlang.term_to_binary(%{
              blknum: blknum,
              hash: insecure_random_bytes(32),
              eth_height: sequence(:block_eth_height, fn seq -> seq end),
              timestamp: sequence(:block_timestamp, fn seq -> seq end),
              transactions: [],
              tx_count: 0
            }),
          blknum: blknum,
          status: DB.PendingBlock.status_pending(),
          retry_count: 0
        }
      end
    end
  end
end

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
  defmacro __using__(_opts) do
    quote do
      alias OMG.WatcherInfo.DB

      @doc """
      Block factory.

      Generates a block in an incremental blknum of 1, 1001, 2001, 3001, etc.
      """
      def block_factory() do
        %DB.Block{
          blknum: sequence(:block_blknum, fn seq -> seq * 1000 + 1 end),
          hash: insecure_random_bytes(32),
          eth_height: sequence(:block_eth_height, fn seq -> seq end),
          timestamp: sequence(:block_timestamp, fn seq -> seq end),
          transactions: []
        }
      end
    end
  end
end

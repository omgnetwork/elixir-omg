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

defmodule OMG.WatcherInfo.BlockApplicatorTest do
  use ExUnitFixtures
  use ExUnit.Case, async: true

  alias OMG.Watcher.BlockGetter.BlockApplication
  alias OMG.WatcherInfo.BlockApplicator
  alias OMG.WatcherInfo.DB

  setup do
      block_application = %BlockApplication{
        number: 1_000,
        eth_height: 1,
        eth_height_done: true,
        hash: "0x1000",
        transactions: [],
        timestamp: 1_576_500_000
      }

      {:ok, block_application: block_application}
  end

  describe "insert_block!" do
    @tag fixtures: [:phoenix_ecto_sandbox]
    test "inserts the given block application into pending block", %{block_application: block_application} do
      assert :ok = BlockApplicator.insert_block!(block_application)

      expected_data =
        :erlang.term_to_binary(%{
          eth_height: block_application.eth_height,
          blknum: block_application.number,
          blkhash: block_application.hash,
          timestamp: block_application.timestamp,
          transactions: block_application.transactions
        })

      assert [%DB.PendingBlock{blknum: 1_000, data: ^expected_data}] = DB.Repo.all(DB.PendingBlock)
    end

    @tag fixtures: [:phoenix_ecto_sandbox]
    test "inserts the the same block does not break", %{block_application: block_application} do
      :ok = BlockApplicator.insert_block!(block_application)

      assert :ok = BlockApplicator.insert_block!(block_application)
    end

    @tag fixtures: [:phoenix_ecto_sandbox]
    test "breaks when block application is invalid", %{block_application: block_application} do
      block_application = %BlockApplication{block_application | number: "not an integer"}

      assert_raise MatchError, fn -> BlockApplicator.insert_block!(block_application) end
    end
  end
end

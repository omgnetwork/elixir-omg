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

defmodule OMG.WatcherInfo.BlockApplicatorTest do
  use ExUnitFixtures
  use ExUnit.Case, async: false

  alias OMG.Watcher.BlockGetter.BlockApplication
  alias OMG.WatcherInfo.BlockApplicator
  alias OMG.WatcherInfo.DB

  import Ecto.Query, only: [where: 2]

  setup do
    eth = <<0::160>>
    alice = OMG.TestHelper.generate_entity()
    tx = OMG.TestHelper.create_recovered([{1, 0, 0, alice}], eth, [{alice, 100}])

    block_application = %BlockApplication{
      number: 1_000,
      eth_height: 1,
      eth_height_done: true,
      hash: "0x1000",
      transactions: [tx],
      timestamp: 1_576_500_000
    }

    {:ok, block_application: block_application}
  end

  describe "insert_block!" do
    @tag fixtures: [:phoenix_ecto_sandbox]
    test "inserts the given block application into pending block", %{block_application: block_application} do
      assert :ok = BlockApplicator.insert_block!(block_application)

      assert [%DB.Block{blknum: 1_000}] = DB.Repo.all(DB.Block)
    end

    @tag fixtures: [:phoenix_ecto_sandbox]
    test "insert block operation is idempotent", %{block_application: block_application} do
      blknum = block_application.number
      :ok = BlockApplicator.insert_block!(block_application)

      assert :ok = BlockApplicator.insert_block!(block_application)
      assert %DB.Block{blknum: ^blknum} = DB.Block |> where(blknum: ^blknum) |> DB.Repo.one()
    end

    @tag fixtures: [:phoenix_ecto_sandbox]
    test "breaks when block application is invalid", %{block_application: block_application} do
      block_application = %BlockApplication{block_application | number: "not an integer"}

      assert_raise MatchError, fn -> BlockApplicator.insert_block!(block_application) end
    end
  end
end

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

defmodule OMG.WatcherInfo.DB.BlockTest do
  use ExUnitFixtures
  use ExUnit.Case, async: false
  use OMG.Fixtures

  alias OMG.Utils.Paginator
  alias OMG.WatcherInfo.DB

  @eth OMG.Eth.RootChain.eth_pseudo_address()

  # TODO: To be replaced by a shared ExUnit.CaseTemplate.setup/0 once #1199 is merged.
  setup do
    {:ok, _pid} =
      Supervisor.start_link(
        [%{id: DB.Repo, start: {DB.Repo, :start_link, []}, type: :supervisor}],
        strategy: :one_for_one
      )

    :ok = Ecto.Adapters.SQL.Sandbox.checkout(DB.Repo)
  end

  # TODO: To be replaced by ExMachina.insert/2 once #1199 is merged.
  defp insert(:block, params) do
    DB.Block
    |> struct(params)
    |> DB.Repo.insert!()
  end

  describe "get_max_blknum/0" do
    test "last consumed block is not set in empty database" do
      assert nil == DB.Block.get_max_blknum()
    end

    test "last consumed block returns correct block number" do
      _ = insert(:block, blknum: 1000, hash: "#1000", eth_height: 1, timestamp: 100)
      _ = insert(:block, blknum: 2000, hash: "#2000", eth_height: 2, timestamp: 200)
      _ = insert(:block, blknum: 3000, hash: "#3000", eth_height: 3, timestamp: 300)

      assert 3000 == DB.Block.get_max_blknum()
    end
  end

  # describe "get_blocks/1" do
  #   @tag fixtures: [:initial_blocks]
  #   test "returns a list of blocks" do
  #     paginator = %Paginator{
  #       data: [],
  #       data_paging: %{
  #         limit: 10,
  #         page: 1
  #       }
  #     }

  #     results = DB.Block.get_blocks(paginator)

  #     assert length(results.data) == 3
  #   end

  #   @tag fixtures: [:initial_blocks]
  #   test "returns a list of blocks sorted by descending blknum" do
  #     paginator = %Paginator{
  #       data: [],
  #       data_paging: %{
  #         limit: 10,
  #         page: 1
  #       }
  #     }

  #     results = DB.Block.get_blocks(paginator)

  #     assert length(results.data) == 3
  #     assert results.data |> Enum.at(0) |> Map.get(:blknum) == 3000
  #     assert results.data |> Enum.at(1) |> Map.get(:blknum) == 2000
  #     assert results.data |> Enum.at(2) |> Map.get(:blknum) == 1000
  #   end

  #   @tag fixtures: [:initial_blocks]
  #   test "returns an empty list when given limit: 0" do
  #     paginator = %Paginator{
  #       data: [],
  #       data_paging: %{
  #         limit: 0,
  #         page: 1
  #       }
  #     }

  #     results = DB.Block.get_blocks(paginator)

  #     assert length(results.data) == 0
  #   end
  # end

  # describe "insert_with_transactions/1" do
  #   @tag fixtures: [:phoenix_ecto_sandbox, :alice, :bob]
  #   test "inserts the block and its transactions", %{alice: alice, bob: bob} do
  #     tx_1 = OMG.TestHelper.create_recovered([{1, 0, 0, alice}], @eth, [{bob, 300}])
  #     tx_2 = OMG.TestHelper.create_recovered([{1, 0, 0, alice}], @eth, [{bob, 500}])

  #     mined_block = %{
  #       transactions: [tx_1, tx_2],
  #       blknum: 1000,
  #       blkhash: "0x12345",
  #       timestamp: DateTime.utc_now() |> DateTime.to_unix(),
  #       eth_height: 1
  #     }

  #     # Check that the block does not exist yet
  #     refute DB.Repo.get(DB.Block, mined_block.blknum)

  #     # Check that the transactions do not exist yet
  #     refute DB.Repo.get(DB.Transaction, tx_1.tx_hash)
  #     refute DB.Repo.get(DB.Transaction, tx_2.tx_hash)

  #     {:ok, block} = DB.Block.insert_with_transactions(mined_block)

  #     # Assert for the inserted block
  #     assert %DB.Block{} = block
  #     assert block.hash == mined_block.blkhash

  #     # Assert for the inserted transactions
  #     assert DB.Repo.get(DB.Transaction, tx_1.tx_hash)
  #     assert DB.Repo.get(DB.Transaction, tx_2.tx_hash)
  #   end

  #   @tag fixtures: [:initial_blocks]
  #   test "returns an error when inserting with an existing blknum", %{initial_blocks: blocks} do
  #     existing_blknum = blocks |> List.first() |> elem(0)

  #     mined_block = %{
  #       transactions: [],
  #       blknum: existing_blknum,
  #       blkhash: "0x12345",
  #       timestamp: DateTime.utc_now() |> DateTime.to_unix(),
  #       eth_height: 100
  #     }

  #     # Check that the block already exists
  #     assert DB.Repo.get(DB.Block, existing_blknum)

  #     {:error, changeset} = DB.Block.insert_with_transactions(mined_block)

  #     assert changeset.errors == [
  #              blknum: {"has already been taken", [constraint: :unique, constraint_name: "blocks_pkey"]}
  #            ]
  #   end
  # end
end

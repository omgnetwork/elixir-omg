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

  import OMG.WatcherInfo.Factory

  alias OMG.Utils.Paginator
  alias OMG.WatcherInfo.DB

  @eth OMG.Eth.RootChain.eth_pseudo_address()

  describe "get_max_blknum/0" do
    @tag fixtures: [:phoenix_ecto_sandbox]
    test "last consumed block is not set in empty database" do
      assert nil == DB.Block.get_max_blknum()
    end

    @tag fixtures: [:phoenix_ecto_sandbox]
    test "last consumed block returns correct block number" do
      _ = insert(:block, blknum: 1000, hash: <<1000>>, eth_height: 1, timestamp: 100)
      _ = insert(:block, blknum: 2000, hash: <<2000>>, eth_height: 2, timestamp: 200)
      _ = insert(:block, blknum: 3000, hash: <<3000>>, eth_height: 3, timestamp: 300)

      assert 3000 == DB.Block.get_max_blknum()
    end
  end

  describe "get_blocks/1" do
    @tag fixtures: [:phoenix_ecto_sandbox]
    test "returns a list of blocks" do
      _ = insert(:block, blknum: 1000, hash: "0x1000", eth_height: 1, timestamp: 100)
      _ = insert(:block, blknum: 2000, hash: "0x2000", eth_height: 2, timestamp: 200)
      _ = insert(:block, blknum: 3000, hash: "0x3000", eth_height: 3, timestamp: 300)

      paginator = %Paginator{
        data: [],
        data_paging: %{
          limit: 10,
          page: 1
        }
      }

      results = DB.Block.get_blocks(paginator)

      assert length(results.data) == 3
      assert Enum.all?(results.data, fn block -> %DB.Block{} = block end)
    end

    @tag fixtures: [:phoenix_ecto_sandbox]
    test "returns a list of blocks sorted by descending blknum" do
      _ = insert(:block, blknum: 1000, hash: "0x1000", eth_height: 1, timestamp: 100)
      _ = insert(:block, blknum: 2000, hash: "0x2000", eth_height: 2, timestamp: 200)
      _ = insert(:block, blknum: 3000, hash: "0x3000", eth_height: 3, timestamp: 300)

      paginator = %Paginator{
        data: [],
        data_paging: %{
          limit: 10,
          page: 1
        }
      }

      results = DB.Block.get_blocks(paginator)

      assert length(results.data) == 3
      assert results.data |> Enum.at(0) |> Map.get(:blknum) == 3000
      assert results.data |> Enum.at(1) |> Map.get(:blknum) == 2000
      assert results.data |> Enum.at(2) |> Map.get(:blknum) == 1000
    end

    @tag fixtures: [:phoenix_ecto_sandbox]
    test "returns an empty list when given limit: 0" do
      paginator = %Paginator{
        data: [],
        data_paging: %{
          limit: 0,
          page: 1
        }
      }

      results = DB.Block.get_blocks(paginator)

      assert results.data == []
    end
  end

  describe "insert_with_transactions/1" do
    @tag fixtures: [:phoenix_ecto_sandbox]
    test "inserts the block, its transactions and transaction outputs" do
      alice = OMG.TestHelper.generate_entity()
      bob = OMG.TestHelper.generate_entity()

      tx_1 = OMG.TestHelper.create_recovered([{1, 0, 0, alice}], @eth, [{bob, 300}])
      tx_2 = OMG.TestHelper.create_recovered([{1, 0, 0, alice}], @eth, [{bob, 500}])

      mined_block = %{
        transactions: [tx_1, tx_2],
        blknum: 1000,
        blkhash: "0x1000",
        timestamp: 1_576_500_000,
        eth_height: 1
      }

      {:ok, block} = DB.Block.insert_with_transactions(mined_block)

      assert %DB.Block{} = block
      assert block.hash == mined_block.blkhash

      assert DB.Repo.get(DB.Transaction, tx_1.tx_hash)
      assert DB.Repo.get(DB.Transaction, tx_2.tx_hash)
    end

    @tag fixtures: [:phoenix_ecto_sandbox]
    test "returns an error when inserting with an existing blknum" do
      existing = insert(:block, blknum: 1000, hash: "0x1000", eth_height: 1, timestamp: 100)

      mined_block = %{
        transactions: [],
        blknum: existing.blknum,
        blkhash: existing.hash,
        timestamp: 1_576_500_000,
        eth_height: existing.eth_height
      }

      {:error, changeset} = DB.Block.insert_with_transactions(mined_block)

      assert changeset.errors == [
               blknum: {"has already been taken", [constraint: :unique, constraint_name: "blocks_pkey"]}
             ]
    end
  end
end

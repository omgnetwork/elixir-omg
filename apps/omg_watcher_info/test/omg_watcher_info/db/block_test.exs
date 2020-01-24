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

defmodule OMG.WatcherInfo.DB.BlockTest do
  use ExUnitFixtures
  use ExUnit.Case, async: false
  use OMG.Fixtures

  import OMG.WatcherInfo.Factory
  import Ecto.Query, only: [from: 2]

  alias OMG.Utils.Paginator
  alias OMG.WatcherInfo.DB

  @eth OMG.Eth.RootChain.eth_pseudo_address()
  @seconds_in_twenty_four_hours 86_400

  describe "base_query" do
    @tag fixtures: [:phoenix_ecto_sandbox]
    test "can be used to retrieve all blocks" do
      _ = insert(:block, blknum: 1000, hash: <<1000>>, eth_height: 1, timestamp: 100)
      _ = insert(:block, blknum: 2000, hash: <<2000>>, eth_height: 2, timestamp: 200)
      _ = insert(:block, blknum: 3000, hash: <<3000>>, eth_height: 3, timestamp: 300)

      result = DB.Repo.all(DB.Block.base_query())

      assert length(result) == 3
      assert Enum.all?(result, fn block -> %DB.Block{} = block end)
    end

    @tag fixtures: [:phoenix_ecto_sandbox]
    test "can be used with a 'where' query expression to retrieve a specific block" do
      _ = insert(:block, blknum: 1000, hash: <<1000>>, eth_height: 1, timestamp: 100)
      _ = insert(:block, blknum: 2000, hash: <<2000>>, eth_height: 2, timestamp: 200)
      _ = insert(:block, blknum: 3000, hash: <<3000>>, eth_height: 3, timestamp: 300)

      target_blknum = 1000

      query =
        from(
          block in DB.Block.base_query(),
          where: [blknum: ^target_blknum]
        )

      result = DB.Repo.one(query)

      assert %DB.Block{} = result
      assert result.blknum == target_blknum
    end

    @tag fixtures: [:phoenix_ecto_sandbox]
    test "includes the transaction count corresponding to a block" do
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

      _ = DB.Block.insert_with_transactions(mined_block)

      tx_count =
        DB.Block.base_query()
        |> DB.Repo.all()
        |> Enum.at(0)
        |> Map.get(:tx_count)

      assert tx_count == 2
    end
  end

  describe "get/1" do
    @tag fixtures: [:phoenix_ecto_sandbox]
    test "retrieves a block by block number" do
      blknum = 1000
      _ = insert(:block, blknum: blknum, hash: "0x#{blknum}", eth_height: 1, timestamp: 100)
      block = DB.Block.get(blknum)
      assert %DB.Block{} = block
      assert block.blknum == blknum
    end

    @tag fixtures: [:phoenix_ecto_sandbox]
    test "returns a correct transaction count if block contains transactions" do
      blknum = 1000

      alice = OMG.TestHelper.generate_entity()
      bob = OMG.TestHelper.generate_entity()
      tx_1 = OMG.TestHelper.create_recovered([{1, 0, 0, alice}], @eth, [{bob, 300}])
      tx_2 = OMG.TestHelper.create_recovered([{1, 0, 0, alice}], @eth, [{bob, 500}])

      mined_block = %{
        transactions: [tx_1, tx_2],
        blknum: blknum,
        blkhash: "0x#{blknum}",
        timestamp: 1_576_500_000,
        eth_height: 1
      }

      _ = DB.Block.insert_with_transactions(mined_block)

      result = DB.Block.get(blknum)

      assert result.tx_count == 2
    end

    @tag fixtures: [:phoenix_ecto_sandbox]
    test "returns a tx_count of zero if block has no transactions" do
      blknum = 1000
      _ = insert(:block, blknum: blknum, hash: "0x#{blknum}", eth_height: 1, timestamp: 100)

      result = DB.Block.get(blknum)

      assert result.tx_count == 0
    end
  end

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

    @tag fixtures: [:phoenix_ecto_sandbox]
    test "returns a correct transaction count if block contains transactions" do
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

      _ = DB.Block.insert_with_transactions(mined_block)

      paginator = %Paginator{
        data: [],
        data_paging: %{
          limit: 10,
          page: 1
        }
      }

      tx_count =
        DB.Block.get_blocks(paginator)
        |> Map.get(:data)
        |> Enum.at(0)
        |> Map.get(:tx_count)

      assert tx_count == 2
    end

    @tag fixtures: [:phoenix_ecto_sandbox]
    test "returns a tx_count of zero if block has no transactions" do
      _ = insert(:block, blknum: 1000, hash: "0x1000", eth_height: 1, timestamp: 100)

      paginator = %Paginator{
        data: [],
        data_paging: %{
          limit: 10,
          page: 1
        }
      }

      tx_count =
        DB.Block.get_blocks(paginator)
        |> Map.get(:data)
        |> Enum.at(0)
        |> Map.get(:tx_count)

      assert tx_count == 0
    end
  end

  describe "count_all/0" do
    @tag fixtures: [:phoenix_ecto_sandbox]
    test "returns correct number of blocks" do
      _ = insert(:block, blknum: 1000, hash: "0x1000", eth_height: 1, timestamp: 100)
      _ = insert(:block, blknum: 2000, hash: "0x2000", eth_height: 2, timestamp: 200)
      _ = insert(:block, blknum: 3000, hash: "0x3000", eth_height: 3, timestamp: 300)

      block_count = DB.Block.count_all()

      assert block_count == 3
    end
  end

  describe "count_all_between_timestamps/2" do
    @tag fixtures: [:phoenix_ecto_sandbox]
    test "returns correct count if blocks have been produced between the two given timestamps" do
      end_datetime = DateTime.to_unix(DateTime.utc_now())
      start_datetime = end_datetime - @seconds_in_twenty_four_hours

      _ = insert(:block, blknum: 1000, hash: "0x1000", eth_height: 1, timestamp: start_datetime + 100)
      _ = insert(:block, blknum: 2000, hash: "0x2000", eth_height: 2, timestamp: start_datetime)
      _ = insert(:block, blknum: 3000, hash: "0x3000", eth_height: 3, timestamp: start_datetime - 100)

      block_count = DB.Block.count_all_between_timestamps(start_datetime, end_datetime)

      assert block_count == 2
    end

    @tag fixtures: [:phoenix_ecto_sandbox]
    test "returns correct count if no blocks have been produced between the two given timestamps" do
      end_datetime = DateTime.to_unix(DateTime.utc_now())
      start_datetime = end_datetime - @seconds_in_twenty_four_hours

      _ = insert(:block, blknum: 1000, hash: "0x1000", eth_height: 1, timestamp: start_datetime - 100)
      _ = insert(:block, blknum: 2000, hash: "0x2000", eth_height: 2, timestamp: start_datetime - 100)
      _ = insert(:block, blknum: 3000, hash: "0x3000", eth_height: 3, timestamp: start_datetime - 100)

      block_count = DB.Block.count_all_between_timestamps(start_datetime, end_datetime)

      assert block_count == 0
    end
  end

  describe "all_timestamps/0" do
    @tag fixtures: [:phoenix_ecto_sandbox]
    test "retrieves all timestamps correctly" do
      _ = insert(:block, blknum: 1000, hash: "0x1000", eth_height: 1, timestamp: 100)
      _ = insert(:block, blknum: 2000, hash: "0x2000", eth_height: 3, timestamp: 200)
      _ = insert(:block, blknum: 3000, hash: "0x3000", eth_height: 3, timestamp: 300)

      timestamps = DB.Block.all_timestamps()

      assert [
               %{timestamp: 100},
               %{timestamp: 200},
               %{timestamp: 300}
             ] == timestamps
    end
  end

  describe "all_timestamps_between/2" do
    @tag fixtures: [:phoenix_ecto_sandbox]
    test "retrieves timestamps filtered by timestamps correctly" do
      end_datetime = DateTime.to_unix(DateTime.utc_now())
      start_datetime = end_datetime - @seconds_in_twenty_four_hours

      _ = insert(:block, blknum: 1000, hash: "0x1000", eth_height: 1, timestamp: start_datetime + 100)
      _ = insert(:block, blknum: 2000, hash: "0x2000", eth_height: 3, timestamp: start_datetime)
      _ = insert(:block, blknum: 3000, hash: "0x3000", eth_height: 3, timestamp: start_datetime - 100)

      timestamps = DB.Block.all_timestamps_between(start_datetime, end_datetime)

      assert [
               %{timestamp: start_datetime + 100},
               %{timestamp: start_datetime}
             ] == timestamps
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

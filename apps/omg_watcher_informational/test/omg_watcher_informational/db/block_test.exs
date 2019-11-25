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

defmodule OMG.WatcherInformational.DB.BlockTest do
  use ExUnitFixtures
  use ExUnit.Case, async: false
  use OMG.Fixtures

  alias OMG.WatcherInformational.DB

  @eth OMG.Eth.RootChain.eth_pseudo_address()

  describe ":initial_blocks fixture" do
    @tag fixtures: [:initial_blocks]
    test "preserves blocks in DB" do
      assert [
               %DB.Block{blknum: 1000, eth_height: 1, hash: "#1000"},
               %DB.Block{blknum: 2000, eth_height: 1, hash: "#2000"},
               %DB.Block{blknum: 3000, eth_height: 1, hash: "#3000"}
             ] = DB.Repo.all(DB.Block)
    end
  end

  describe "get_max_blknum/0" do
    @tag fixtures: [:phoenix_ecto_sandbox]
    test "last consumed block is not set in empty database" do
      assert nil == DB.Block.get_max_blknum()
    end

    @tag fixtures: [:initial_blocks]
    test "last consumed block returns correct block number" do
      assert 3000 == DB.Block.get_max_blknum()
    end
  end

  describe "insert_with_transactions/1" do
    @tag fixtures: [:phoenix_ecto_sandbox, :alice, :bob]
    test "inserts the block and its transactions", %{alice: alice, bob: bob} do
      tx_1 = OMG.TestHelper.create_recovered([{1, 0, 0, alice}], @eth, [{bob, 300}])
      tx_2 = OMG.TestHelper.create_recovered([{1, 0, 0, alice}], @eth, [{bob, 500}])

      mined_block = %{
        transactions: [tx_1, tx_2],
        blknum: 1000,
        blkhash: "0x12345",
        timestamp: DateTime.utc_now() |> DateTime.to_unix(),
        eth_height: 1
      }

      # Check that the block does not exist yet
      refute DB.Repo.get(DB.Block, mined_block.blknum)

      # Check that the transactions do not exist yet
      refute DB.Repo.get(DB.Transaction, tx_1.tx_hash)
      refute DB.Repo.get(DB.Transaction, tx_2.tx_hash)

      {:ok, block} = DB.Block.insert_with_transactions(mined_block)

      # Assert for the inserted block
      assert %DB.Block{} = block
      assert block.hash == mined_block.blkhash

      # Assert for the inserted transactions
      assert DB.Repo.get(DB.Transaction, tx_1.tx_hash)
      assert DB.Repo.get(DB.Transaction, tx_2.tx_hash)
    end

    @tag fixtures: [:initial_blocks]
    test "returns an error when inserting with an existing blknum", %{initial_blocks: blocks} do
      existing_blknum = blocks |> List.first() |> elem(0)

      mined_block = %{
        transactions: [],
        blknum: existing_blknum,
        blkhash: "0x12345",
        timestamp: DateTime.utc_now() |> DateTime.to_unix(),
        eth_height: 100
      }

      # Check that the block already exists
      assert DB.Repo.get(DB.Block, existing_blknum)

      {:error, changeset} = DB.Block.insert_with_transactions(mined_block)
      assert changeset.errors == [blknum: {"has already been taken", [constraint: :unique, constraint_name: "blocks_pkey"]}]
    end
  end
end

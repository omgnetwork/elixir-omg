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

defmodule OMG.WatcherInfo.API.BlockTest do
  use OMG.WatcherInfo.DataCase, async: true
  import OMG.WatcherInfo.Factory

  alias OMG.Utils.Paginator
  alias OMG.WatcherInfo.API
  alias OMG.WatcherInfo.DB

  describe "get/1" do
    test "returns block by block number" do
      inserted = insert(:block, blknum: 1000, hash: "0x1000", eth_height: 1, timestamp: 100)

      {:ok, block} = API.Block.get(inserted.blknum)
      assert block.hash == inserted.hash
    end

    test "returns expected error if block not found" do
      non_existent_block = 5000
      assert API.Block.get(non_existent_block) == {:error, :block_not_found}
    end
  end

  describe "get_blocks/1" do
    test "returns a paginator with a list of blocks" do
      _ = insert(:block, blknum: 1000, hash: "0x1000", eth_height: 1, timestamp: 100)
      _ = insert(:block, blknum: 2000, hash: "0x2000", eth_height: 2, timestamp: 200)
      _ = insert(:block, blknum: 3000, hash: "0x3000", eth_height: 3, timestamp: 300)

      constraints = []
      results = API.Block.get_blocks(constraints)

      assert %Paginator{} = results
      assert length(results.data) == 3
      assert Enum.all?(results.data, fn block -> %DB.Block{} = block end)
    end

    test "returns a paginator according to the provided paginator constraints" do
      _inserted_1 = insert(:block, blknum: 1000, hash: "0x1000", eth_height: 1, timestamp: 100)
      inserted_2 = insert(:block, blknum: 2000, hash: "0x2000", eth_height: 2, timestamp: 200)
      inserted_3 = insert(:block, blknum: 3000, hash: "0x3000", eth_height: 3, timestamp: 300)

      constraints = [limit: 2, page: 1]
      results = API.Block.get_blocks(constraints)

      assert %Paginator{} = results
      assert length(results.data) == 2
      assert results.data |> Enum.at(0) |> Map.get(:blknum) == inserted_3.blknum
      assert results.data |> Enum.at(1) |> Map.get(:blknum) == inserted_2.blknum
    end
  end
end

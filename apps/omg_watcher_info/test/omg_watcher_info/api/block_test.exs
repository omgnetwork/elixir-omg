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

defmodule OMG.WatcherInfo.API.BlockTest do
  use ExUnitFixtures
  use ExUnit.Case, async: false
  use OMG.Fixtures
  use OMG.WatcherInfo.Fixtures
  use OMG.Watcher.Fixtures

  alias OMG.WatcherInfo.DB
  alias OMG.WatcherInfo.API.Block

  describe "get_block/1" do
    @tag fixtures: [:initial_blocks]
    test "returns block by id" do
      block_hash = "##{1000}"
      block = DB.Block.get(block_hash)
      assert {:ok, block} == Block.get(block_hash)
    end

    @tag fixtures: [:initial_blocks]
    test "returns expected error if block not found" do
      non_existent_block = "##{5000}"
      assert {:error, :block_not_found} == Block.get(non_existent_block)
    end
  end
end

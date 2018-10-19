# Copyright 2018 OmiseGO Pte Ltd
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

defmodule OMG.Watcher.DB.BlockTest do
  use ExUnitFixtures
  use ExUnit.Case, async: false
  use OMG.API.Fixtures

  alias OMG.Watcher.DB

  describe "Block table" do
    @tag fixtures: [:initial_blocks]
    test "initial data preserve blocks in DB" do
      assert [
               %DB.Block{blknum: 1000, eth_height: 1, hash: "#1000", timestamp: _ts},
               %DB.Block{blknum: 2000, eth_height: 1, hash: "#2000", timestamp: _ts},
               %DB.Block{blknum: 3000, eth_height: 1, hash: "#3000", timestamp: _ts}
             ] = DB.Block.get_all()
    end

    @tag fixtures: [:initial_blocks]
    test "transaction belongs to block can retrieve it by association" do
      assert %DB.Transaction{
               blknum: 3000,
               txindex: 1,
               block: %DB.Block{blknum: 3000}
             } =
               DB.Transaction.get_by_position(3000, 1)
               |> DB.Repo.preload(:block)
    end
  end
end

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
end

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

defmodule OMG.WatcherInfo.DB.RepoTest do
  use OMG.WatcherInfo.Test.DBTestCase, async: true

  import Ecto.Query, only: [from: 2]

  import OMG.WatcherInfo.Factory

  # test "insert_all_chunked adds inserted_at and updated_at timestamps correctly" do
  #   blknum = 5432

  #   block = %{blknum: blknum, eth_height: 1, hash: "#1000", timestamp: 1}

  #   DB.Repo.insert_all_chunked(OMG.Watcher.DB.Block, [block])

  #   db_block = DB.Repo.one(from(block in OMG.Watcher.DB.Block, where: block.blknum == ^blknum))

  #   # on insert inserted_at and updated_at should be approximately equal or updated_at will be greater
  #   assert DateTime.compare(db_block.inserted_at, db_block.updated_at) == :lt ||
  #            DateTime.compare(db_block.inserted_at, db_block.updated_at) == :eq

  #   DB.Repo.delete(db_block)
  # end

  test "factory works" do
    block = insert(:block)

    IO.inspect(block, label: "block")
  end
end

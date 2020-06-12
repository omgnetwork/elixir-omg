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

defmodule OMG.WatcherInfo.DB.PendingBlockTest do
  use ExUnitFixtures
  use ExUnit.Case, async: true
  use OMG.Fixtures

  import OMG.WatcherInfo.Factory

  alias OMG.WatcherInfo.DB
  alias OMG.WatcherInfo.DB.PendingBlock

  describe "insert/1" do
    @tag fixtures: [:phoenix_ecto_sandbox]
    test "casts blknum and data" do
      data = :erlang.term_to_binary(%{something: :nice})
      assert {:ok, block} = PendingBlock.insert(%{data: data, blknum: 1000, bad_key: :value})

      assert %PendingBlock{blknum: 1000, data: data} = block
    end

    @tag fixtures: [:phoenix_ecto_sandbox]
    test "returns an error if blknum is already used" do
      blknum = 1000
      insert(:pending_block, %{data: <<0>>, blknum: blknum})

      assert {:error, %Ecto.Changeset{}} = PendingBlock.insert(%{data: <<1>>, blknum: blknum})
    end
  end

  describe "get_next_to_process/0" do
    @tag fixtures: [:phoenix_ecto_sandbox]
    test "returns the next pending block" do
      b_1 = insert(:pending_block)
      b_2 = insert(:pending_block)
      _b_3 = insert(:pending_block)

      assert PendingBlock.get_next_to_process() == b_1

      {:ok, _} = DB.Repo.delete(b_1)

      assert PendingBlock.get_next_to_process() == b_2
    end

    @tag fixtures: [:phoenix_ecto_sandbox]
    test "returns nil if no block to process" do
      assert PendingBlock.get_next_to_process() == nil
    end
  end

  describe "get_count/0" do
    test "returns the count of pending blocks" do
      assert PendingBlock.get_count() == 0

      insert(:pending_block)
      insert(:pending_block)
      insert(:pending_block)

      assert PendingBlock.get_count() == 3
    end
  end
end

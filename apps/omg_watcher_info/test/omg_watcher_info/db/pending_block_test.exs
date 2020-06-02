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
  use OMG.WatcherInfo.DBCase, async: true

  alias OMG.WatcherInfo.DB.PendingBlock

  describe "insert/1" do
    test "casts blknum and data" do
      data = :erlang.term_to_binary(%{something: :nice})
      assert {:ok, block} = PendingBlock.insert(%{data: data, blknum: 1000, bad_key: :value})

      assert %PendingBlock{blknum: 1000, data: data} = block
    end

    test "default status to pending and retry count to 0" do
      assert {:ok, %{retry_count: 0, status: "pending"}} = PendingBlock.insert(%{data: <<0>>, blknum: 1000})
    end

    test "does not cast retry count and status" do
      assert {:ok, %{retry_count: 0, status: "pending"}} =
               PendingBlock.insert(%{data: <<0>>, blknum: 1000, status: "1337", retry_count: 1337})
    end

    test "returns an error if blknum is already used" do
      blknum = 1000
      insert(:pending_block, %{data: <<0>>, blknum: blknum})

      assert {:error, %Ecto.Changeset{}} = PendingBlock.insert(%{data: <<1>>, blknum: blknum})
    end
  end

  describe "increment_retry_count/1" do
    test "increment the retry counter" do
      %{retry_count: 0} = pending_block = insert(:pending_block)
      assert {:ok, %{retry_count: 1}} = PendingBlock.increment_retry_count(pending_block)
    end

    test "does not modify other keys" do
      pending_block = insert(:pending_block)
      {:ok, updated_block} = PendingBlock.increment_retry_count(pending_block)
      assert pending_block.data == updated_block.data
      assert pending_block.blknum == updated_block.blknum
      assert pending_block.status == updated_block.status
      assert pending_block.inserted_at == updated_block.inserted_at
      assert pending_block.updated_at < updated_block.updated_at
    end
  end

  describe "get_next_to_process/0" do
    test "returns the next pending block" do
      b_1 = insert(:pending_block)
      b_2 = insert(:pending_block)
      _b_3 = insert(:pending_block)

      {:ok, _} = b_1 |> PendingBlock.done_changeset() |> DB.Repo.update()

      assert PendingBlock.get_next_to_process() == b_2
    end

    test "returns nil if no block to process" do
      assert PendingBlock.get_next_to_process() == nil

      b_1 = insert(:pending_block)
      {:ok, _} = b_1 |> PendingBlock.done_changeset() |> DB.Repo.update()

      assert PendingBlock.get_next_to_process() == nil
    end
  end

  describe "done_changeset/1" do
    test "returns changeset with status done" do
      b_1 = insert(:pending_block)

      assert %{changes: %{status: "done"}} = PendingBlock.done_changeset(b_1)
    end
  end
end

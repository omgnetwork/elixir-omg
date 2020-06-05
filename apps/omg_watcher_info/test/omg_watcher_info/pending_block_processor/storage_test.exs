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

defmodule OMG.WatcherInfo.PendingBlockProcessor.StorageTest do
  use ExUnitFixtures
  use ExUnit.Case, async: true

  import OMG.WatcherInfo.Factory
  import Ecto.Query, only: [from: 2]

  alias OMG.WatcherInfo.DB
  alias OMG.WatcherInfo.DB.PendingBlock
  alias OMG.WatcherInfo.PendingBlockProcessor.Storage

  describe "get_next_pending_block/0" do
    @tag fixtures: [:phoenix_ecto_sandbox]
    test "returns the next block to process when exist" do
      %{blknum: blknum} = insert(:pending_block)

      assert %{blknum: ^blknum} = Storage.get_next_pending_block()
    end

    @tag fixtures: [:phoenix_ecto_sandbox]
    test "returns nil when no pending block" do
      assert Storage.get_next_pending_block() == nil
    end
  end

  describe "process_block/1" do
    @tag fixtures: [:phoenix_ecto_sandbox]
    test "insert the block into the storage and set its status to done" do
      block = insert(:pending_block)

      assert Storage.process_block(block) == :ok

      assert [%{status: "done"}] = get_all()
    end

    @tag fixtures: [:phoenix_ecto_sandbox]
    test "returns an error and increase retry count when failing" do
      %{data: data, blknum: blknum_1} = block_1 = insert(:pending_block)
      assert Storage.process_block(block_1) == :ok

      # inserting a second block with the same data params
      %{blknum: blknum_2, retry_count: 0} = block_2 = insert(:pending_block, %{data: data, blknum: blknum_1 + 1000})

      assert Storage.process_block(block_2) == :error

      assert [%{blknum: ^blknum_1}, %{blknum: ^blknum_2, retry_count: 1}] = get_all()
    end
  end

  describe "increment_retry_count/1" do
    @tag fixtures: [:phoenix_ecto_sandbox]
    test "increments the retry count of a pending block" do
      %{retry_count: 0} = block = insert(:pending_block)
      {:ok, %{retry_count: 1}} = PendingBlock.increment_retry_count(block)
    end
  end

  defp get_all() do
    PendingBlock |> from(order_by: :blknum) |> DB.Repo.all()
  end
end

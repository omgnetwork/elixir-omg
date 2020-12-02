# Copyright 2019-2020 OMG Network Pte Ltd
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

defmodule OMG.WatcherInfo.PendingBlockQueueLengthChecker.StorageTest do
  use ExUnitFixtures
  use ExUnit.Case, async: false

  import OMG.WatcherInfo.Factory

  alias OMG.WatcherInfo.DB
  alias OMG.WatcherInfo.PendingBlockQueueLengthChecker.Storage

  describe "get_queue_length/0" do
    @tag fixtures: [:phoenix_ecto_sandbox]
    test "returns the queue length" do
      assert Storage.get_queue_length() == 0

      block_1 = insert(:pending_block)
      block_2 = insert(:pending_block)
      block_3 = insert(:pending_block)

      assert Storage.get_queue_length() == 3

      DB.Repo.delete!(block_1)
      DB.Repo.delete!(block_2)
      DB.Repo.delete!(block_3)

      assert Storage.get_queue_length() == 0
    end
  end
end

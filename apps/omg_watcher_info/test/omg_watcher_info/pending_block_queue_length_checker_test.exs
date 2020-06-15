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

defmodule OMG.WatcherInfo.PendingBlockQueueLengthCheckerTest do
  use ExUnitFixtures
  use ExUnit.Case, async: true

  import OMG.WatcherInfo.Factory

  alias OMG.WatcherInfo.DB
  alias OMG.WatcherInfo.PendingBlockQueueLengthChecker

  @interval 100

  setup tags do
    {:ok, _pid} =
      PendingBlockQueueLengthChecker.start_link(
        check_interval: @interval,
        name: PendingBlockQueueLengthCheckerTest
      )

    handler_id = {__MODULE__, :rand.uniform(100)}

    on_exit(fn ->
      :telemetry.detach(handler_id)
    end)

    Map.put(tags, :handler_id, handler_id)
  end

  describe "handle_info/2" do
    @tag fixtures: [:phoenix_ecto_sandbox]
    test "emits a pending_block_queue_length event with the length", %{handler_id: handler_id} do
      attach(handler_id, [:pending_block_queue_length, PendingBlockQueueLengthChecker])

      assert_receive(
        {:telemetry_event, [:pending_block_queue_length, PendingBlockQueueLengthChecker], %{length: 0}, %{}},
        @interval * 2
      )

      block_1 = insert(:pending_block)

      assert_receive(
        {:telemetry_event, [:pending_block_queue_length, PendingBlockQueueLengthChecker], %{length: 1}, %{}},
        @interval * 2
      )

      block_2 = insert(:pending_block)

      assert_receive(
        {:telemetry_event, [:pending_block_queue_length, PendingBlockQueueLengthChecker], %{length: 2}, %{}},
        @interval * 2
      )

      block_3 = insert(:pending_block)

      assert_receive(
        {:telemetry_event, [:pending_block_queue_length, PendingBlockQueueLengthChecker], %{length: 3}, %{}},
        @interval * 2
      )

      DB.Repo.delete!(block_1)

      assert_receive(
        {:telemetry_event, [:pending_block_queue_length, PendingBlockQueueLengthChecker], %{length: 2}, %{}},
        @interval * 2
      )

      DB.Repo.delete!(block_2)

      assert_receive(
        {:telemetry_event, [:pending_block_queue_length, PendingBlockQueueLengthChecker], %{length: 1}, %{}},
        @interval * 2
      )

      DB.Repo.delete!(block_3)

      assert_receive(
        {:telemetry_event, [:pending_block_queue_length, PendingBlockQueueLengthChecker], %{length: 0}, %{}},
        @interval * 2
      )
    end
  end

  defp attach(handler_id, event) do
    pid = self()

    :telemetry.attach(
      handler_id,
      event,
      fn received_event, measurements, metadata, _ ->
        send(pid, {:telemetry_event, received_event, measurements, metadata})
      end,
      nil
    )
  end
end

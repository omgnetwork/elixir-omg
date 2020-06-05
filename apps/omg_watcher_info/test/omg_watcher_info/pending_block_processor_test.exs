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

defmodule OMG.WatcherInfo.PendingBlockProcessorTest do
  use ExUnitFixtures
  use ExUnit.Case, async: true

  import OMG.WatcherInfo.Factory
  import Ecto.Query, only: [from: 2]

  alias OMG.WatcherInfo.DB
  alias OMG.WatcherInfo.DB.PendingBlock
  alias OMG.WatcherInfo.PendingBlockProcessor

  @interval 500

  setup tags do
    {:ok, pid} =
      PendingBlockProcessor.start_link(
        processing_interval: @interval,
        name: tags.test
      )

    %{timer: t_ref} = :sys.get_state(pid)
    _ = Process.cancel_timer(t_ref)

    _ =
      on_exit(fn ->
        if Process.alive?(pid), do: :ok = GenServer.stop(pid)
      end)

    Map.put(tags, :pid, pid)
  end

  describe "handle_info/2" do
    @tag fixtures: [:phoenix_ecto_sandbox]
    test "processes the next pending block in queue", %{pid: pid} do
      %{timer: tref} = get_state(pid)
      assert Process.read_timer(tref) == false

      %{blknum: blknum} = insert(:pending_block)

      assert [%{status: "pending", blknum: ^blknum}] = get_all()
      assert [] = DB.Repo.all(DB.Block)

      perform_timer_action(pid)

      assert [%{status: "done", blknum: ^blknum}] = get_all()
      assert [%{blknum: ^blknum}] = DB.Repo.all(DB.Block)
    end

    @tag fixtures: [:phoenix_ecto_sandbox]
    test "schedules a new update after `interval` when queue was empty", %{pid: pid} do
      %{timer: tref_1} = get_state(pid)
      assert Process.read_timer(tref_1) == false
      assert get_all() == []

      %{timer: tref_2} = perform_timer_action(pid)

      assert tref_1 != tref_2
      assert Process.read_timer(tref_2) in 0..@interval
    end

    @tag fixtures: [:phoenix_ecto_sandbox]
    test "does not schedules a new update after `interval` when queue not empty", %{pid: pid} do
      insert(:pending_block)
      assert [%{}] = get_all()

      %{timer: tref} = perform_timer_action(pid)

      assert tref == nil
    end

    @tag fixtures: [:phoenix_ecto_sandbox]
    test "check the queue again without waiting when queue not empty", %{pid: pid} do
      insert(:pending_block)
      insert(:pending_block)

      assert [%{status: "pending"}, %{status: "pending"}] = get_all()

      assert %{timer: nil} = perform_timer_action(pid)
      Process.sleep(50)
      assert [%{status: "done"}, %{status: "done"}] = get_all()
    end

    @tag fixtures: [:phoenix_ecto_sandbox]
    test "increments retry count when failing", %{pid: pid} do
      %{data: data, blknum: blknum_1} = insert(:pending_block)
      perform_timer_action(pid)

      # inserting a second block with the same data params
      %{blknum: blknum_2, retry_count: 0} = insert(:pending_block, %{data: data, blknum: blknum_1 + 1000})
      perform_timer_action(pid)

      assert [%{blknum: ^blknum_1}, %{blknum: ^blknum_2, retry_count: retry_count}] = get_all()
      assert retry_count > 0
      assert [%{blknum: blknum_1}] = DB.Repo.all(DB.Block)
    end
  end

  defp get_all() do
    PendingBlock |> from(order_by: :blknum) |> DB.Repo.all()
  end

  defp perform_timer_action(pid) do
    Process.send(pid, :check_queue, [:noconnect])
    # this waits for all messages in process inbox is processed
    get_state(pid)
  end

  defp get_state(pid) do
    :sys.get_state(pid)
  end
end

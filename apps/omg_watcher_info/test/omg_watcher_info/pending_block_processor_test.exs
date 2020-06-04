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

      assert [%{status: "pending", blknum: ^blknum}] = DB.Repo.all(PendingBlock)
      assert [] = DB.Repo.all(DB.Block)

      perform_timer_action(pid)

      assert [%{status: "done", blknum: ^blknum}] = DB.Repo.all(PendingBlock)
      assert [%{blknum: ^blknum}] = DB.Repo.all(DB.Block)
    end

    @tag fixtures: [:phoenix_ecto_sandbox]
    test "schedules a new update after `interval`", %{pid: pid} do
      %{timer: tref_1} = get_state(pid)
      assert Process.read_timer(tref_1) == false

      perform_timer_action(pid)

      %{timer: tref_2} = get_state(pid)
      assert tref_1 != tref_2
      assert Process.read_timer(tref_2) in 0..@interval
    end

    @tag fixtures: [:phoenix_ecto_sandbox]
    test "increments retry count when failing", %{pid: pid} do
      invalid_block_params = %{
        data:
          :erlang.term_to_binary(%{
            blknum: 0,
            blkhash: insecure_random_bytes(32),
            eth_height: 0,
            timestamp: 0,
            transactions: [],
            tx_count: 0
          }),
        blknum: 0
      }

      assert %{blknum: blknum, retry_count: 0} = insert(:pending_block, invalid_block_params)

      perform_timer_action(pid)

      assert [%{status: "pending", blknum: ^blknum, retry_count: 1}] = DB.Repo.all(PendingBlock)
      assert [] = DB.Repo.all(DB.Block)
    end
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

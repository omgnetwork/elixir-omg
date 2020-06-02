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
  use ExUnit.Case, async: false

  import OMG.WatcherInfo.Factory

  alias OMG.TestHelper
  alias OMG.Watcher.BlockGetter.BlockApplication
  alias OMG.WatcherInfo.PendingBlockProcessor
  alias OMG.WatcherInfo.DB
  alias OMG.WatcherInfo.DB.PendingBlock

  @eth OMG.Eth.zero_address()
  @interval 500

  setup_all do
    {:ok, pid} =
      GenServer.start_link(
        PendingBlockProcessor,
        [processing_interval: @interval],
        name: TestPendingBlockProcessor
      )

    # Cancelling timer so it doesn't interfere with our tests
    %{timer: t_ref} = :sys.get_state(pid)
    _ = Process.cancel_timer(t_ref)

    _ =
      on_exit(fn ->
        with pid when is_pid(pid) <- GenServer.whereis(TestPendingBlockProcessor) do
          :ok = GenServer.stop(TestPendingBlockProcessor)
        end
      end)
  end

  describe "handle_info/2" do
    @tag fixtures: [:phoenix_ecto_sandbox]
    test "process next pending block in queue" do
      %{timer: tref} = get_state()
      assert Process.read_timer(tref) == false

      %{blknum: blknum} = insert(:pending_block)

      assert [%{status: "pending", blknum: ^blknum}] = DB.Repo.all(DB.PendingBlock)
      assert [] = DB.Repo.all(DB.Block)

      perform_timer_action()

      assert [%{status: "done", blknum: ^blknum}] = DB.Repo.all(DB.PendingBlock)
      assert [%{blknum: ^blknum}] = DB.Repo.all(DB.Block)
    end

    test "schedules a new update after `interval`" do
    end
  end

  defp perform_timer_action() do
    pid = assert_consumer_alive()

    Process.send(pid, :check_queue, [:noconnect])
    # this waits for all messages in process inbox is processed
    :sys.get_state(pid)
  end

  defp get_state() do
    :sys.get_state(assert_consumer_alive())
  end

  defp assert_consumer_alive() do
    pid = GenServer.whereis(TestPendingBlockProcessor)
    assert is_pid(pid) and Process.alive?(pid)
    pid
  end
end

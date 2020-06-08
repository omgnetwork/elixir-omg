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

  alias OMG.WatcherInfo.PendingBlockProcessor

  @interval 100

  defmodule DumbStorage do
    use GenServer

    def start_link(args) do
      GenServer.start_link(__MODULE__, args, name: __MODULE__)
    end

    def init(args) do
      # note: each mock will set the state of the corresponding
      # function name to {count, metadata} where count represents the amount of time
      # the function was called and metadata is a map of additional info.
      default_state = %{
        get_next_pending_block: {0, nil},
        process_block: {0, nil},
        increment_retry_count: {0, nil},
        next_pending_block: nil
      }

      given_state = Enum.into(args, %{})
      state = Map.merge(default_state, given_state)
      {:ok, state}
    end

    def get_next_pending_block() do
      GenServer.call(__MODULE__, :get_next_pending_block)
    end

    def process_block(block) do
      GenServer.call(__MODULE__, {:process_block, block})
    end

    def increment_retry_count(block) do
      GenServer.call(__MODULE__, {:increment_retry_count, block})
    end

    def handle_call(:get_next_pending_block, _from, %{get_next_pending_block: {count, _}} = state) do
      {:reply, state.next_pending_block, %{state | get_next_pending_block: {count + 1, state.next_pending_block}}}
    end

    def handle_call({:process_block, block}, _from, %{process_block: {count, _}} = state) do
      {:reply, nil, %{state | process_block: {count + 1, block}}}
    end

    def handle_call({:increment_retry_count, block}, _from, %{increment_retry_count: {count, _}} = state) do
      {:reply, nil, %{state | increment_retry_count: {count + 1, block}}}
    end
  end

  setup tags do
    {:ok, pid} =
      PendingBlockProcessor.start_link(
        processing_interval: @interval,
        storage_module: DumbStorage,
        name: tags.test
      )

    _ =
      on_exit(fn ->
        if Process.alive?(pid), do: :ok = GenServer.stop(pid)
        storage_pid = GenServer.whereis(DumbStorage)
        if storage_pid != nil and Process.alive?(storage_pid), do: :ok = GenServer.stop(storage_pid)
      end)

    Map.put(tags, :pid, pid)
  end

  describe "handle_info/2" do
    test "calls get_next_pending_block/0 when triggered", %{pid: pid} do
      storage_pid = start_storage_mock()

      perform_timout_action(pid)

      assert %{get_next_pending_block: {1, nil}} = get_state(storage_pid)
    end

    test "is triggered on startup after `interval` ms" do
      storage_pid = start_storage_mock()

      assert %{get_next_pending_block: {0, nil}} = get_state(storage_pid)

      Process.sleep(@interval + 1)

      assert %{get_next_pending_block: {1, nil}} = get_state(storage_pid)
    end

    test "does not call storage.process_block/1 when no pending block", %{pid: pid} do
      storage_pid = start_storage_mock()

      perform_timout_action(pid)

      assert %{get_next_pending_block: {1, nil}, process_block: {0, nil}} = get_state(storage_pid)
    end

    test "schedule an update after `interval` when no pending block", %{pid: pid} do
      storage_pid = start_storage_mock()

      perform_timout_action(pid)

      assert %{get_next_pending_block: {1, nil}} = get_state(storage_pid)

      Process.sleep(@interval + 1)

      assert %{get_next_pending_block: {2, nil}} = get_state(storage_pid)
    end

    test "calls process_block with the pending block when present", %{pid: pid} do
      block = build(:pending_block)

      {:ok, storage_pid} = DumbStorage.start_link(next_pending_block: block)

      perform_timout_action(pid)

      assert %{get_next_pending_block: {1, ^block}, process_block: {1, ^block}} = get_state(storage_pid)
    end

    test "schedule a check after 1 ms when there was a pending block to process", %{pid: pid} do
      block = build(:pending_block)

      {:ok, storage_pid} = DumbStorage.start_link(next_pending_block: block)

      perform_timout_action(pid)

      assert %{get_next_pending_block: {1, ^block}, process_block: {1, ^block}} = get_state(storage_pid)

      Process.sleep(2)

      assert %{get_next_pending_block: {count, _}} = get_state(storage_pid)

      assert count >= 2
    end
  end

  defp start_storage_mock() do
    {:ok, storage_pid} = DumbStorage.start_link([])
    storage_pid
  end

  defp perform_timout_action(pid) do
    Process.send(pid, :timeout, [:noconnect])
    # this waits for all messages in process inbox is processed
    get_state(pid)
  end

  defp get_state(pid) do
    :sys.get_state(pid)
  end
end

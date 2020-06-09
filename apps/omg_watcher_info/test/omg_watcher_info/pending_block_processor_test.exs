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

  import Ecto.Query, only: [from: 2]
  import OMG.WatcherInfo.Factory

  alias OMG.WatcherInfo.DB
  alias OMG.WatcherInfo.DB.PendingBlock
  alias OMG.WatcherInfo.PendingBlockProcessor
  alias OMG.WatcherInfo.PendingBlockProcessor.Storage

  @interval 200

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

    def handle_call(:get_next_pending_block, _from, %{get_next_pending_block: {count, _}} = state) do
      {:reply, state.next_pending_block, %{state | get_next_pending_block: {count + 1, state.next_pending_block}}}
    end

    def handle_call({:process_block, block}, _from, %{process_block: {count, _}} = state) do
      {:reply, {:ok, nil}, %{state | process_block: {count + 1, block}}}
    end
  end

  defp setup_with_storage(storage, tags) do
    {:ok, pid} =
      PendingBlockProcessor.start_link(
        processing_interval: @interval,
        storage_module: storage,
        name: PendingBlockProcessorTest
      )

    Map.put(tags, :pid, pid)
  end

  describe "handle_info/2 with mocked Storage" do
    setup tags do
      setup_with_storage(DumbStorage, tags)
    end

    test "calls get_next_pending_block/0 when triggered", %{pid: pid} do
      storage_pid = start_storage_mock()

      :erlang.trace(pid, true, [:receive])
      assert_receive {:trace, ^pid, :receive, :timeout}, @interval + 1

      assert %{get_next_pending_block: {1, nil}} = get_state(storage_pid)
    end

    test "is triggered on startup after `interval` ms", %{pid: pid} do
      storage_pid = start_storage_mock()

      assert %{get_next_pending_block: {0, nil}} = get_state(storage_pid)

      :erlang.trace(pid, true, [:receive])
      assert_receive {:trace, ^pid, :receive, :timeout}, @interval + 1

      assert %{get_next_pending_block: {1, nil}} = get_state(storage_pid)
    end

    test "does not call storage.process_block/1 when no pending block", %{pid: pid} do
      storage_pid = start_storage_mock()

      :erlang.trace(pid, true, [:receive])
      assert_receive {:trace, ^pid, :receive, :timeout}, @interval + 1

      assert %{get_next_pending_block: {1, nil}, process_block: {0, nil}} = get_state(storage_pid)
    end

    test "schedule an update after `interval` when no pending block", %{pid: pid} do
      :erlang.trace(pid, true, [:receive])

      storage_pid = start_storage_mock()

      assert_receive {:trace, ^pid, :receive, :timeout}, @interval + 1

      assert %{get_next_pending_block: {1, nil}} = get_state(storage_pid)

      assert_receive {:trace, ^pid, :receive, :timeout}, @interval + 1

      assert %{get_next_pending_block: {2, nil}} = get_state(storage_pid)
    end

    test "calls process_block with the pending block when present", %{pid: pid} do
      :erlang.trace(pid, true, [:receive])
      block = build(:pending_block)

      {:ok, storage_pid} = DumbStorage.start_link(next_pending_block: block)

      assert_receive {:trace, ^pid, :receive, :timeout}, @interval + 1
      get_state(pid)

      assert %{get_next_pending_block: {1, ^block}, process_block: {1, ^block}} = get_state(storage_pid)
    end

    test "schedule a check after 1 ms when there was a pending block to process", %{pid: pid} do
      :erlang.trace(pid, true, [:receive])

      block = build(:pending_block)

      {:ok, storage_pid} = DumbStorage.start_link(next_pending_block: block)

      assert_receive {:trace, ^pid, :receive, :timeout}, @interval + 1
      get_state(pid)

      assert %{get_next_pending_block: {1, ^block}, process_block: {1, ^block}} = get_state(storage_pid)

      assert_receive {:trace, ^pid, :receive, :timeout}

      assert %{get_next_pending_block: {2, _}} = get_state(storage_pid)
    end
  end

  describe "handle_info/2 with real Storage" do
    setup tags do
      setup_with_storage(Storage, tags)
    end

    @tag fixtures: [:phoenix_ecto_sandbox]
    test "processes the next pending block in queue", %{pid: pid} do
      :erlang.trace(pid, true, [:receive])

      %{blknum: blknum_1} = insert(:pending_block)
      %{blknum: blknum_2} = insert(:pending_block)
      %{blknum: blknum_3} = insert(:pending_block)

      assert_receive {:trace, ^pid, :receive, :timeout}, @interval + 1
      get_state(pid)

      assert [%{blknum: ^blknum_1, status: "done"}, %{status: "pending"}, %{status: "pending"}] = get_all()

      assert_receive {:trace, ^pid, :receive, :timeout}
      get_state(pid)

      assert [%{}, %{blknum: ^blknum_2, status: "done"}, %{status: "pending"}] = get_all()

      assert_receive {:trace, ^pid, :receive, :timeout}
      get_state(pid)

      assert [%{}, %{}, %{blknum: ^blknum_3, status: "done"}] = get_all()
    end
  end

  defp get_all() do
    PendingBlock |> from(order_by: :blknum) |> DB.Repo.all()
  end

  defp start_storage_mock() do
    {:ok, storage_pid} = DumbStorage.start_link([])
    storage_pid
  end

  defp get_state(pid) do
    :sys.get_state(pid)
  end
end

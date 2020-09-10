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

defmodule OMG.ChildChain.BlockQueue.SubmissionMonitorTest do
  use ExUnit.Case, async: true
  import ExUnit.CaptureLog, only: [capture_log: 1]
  alias OMG.ChildChain.BlockQueue.SubmissionMonitor

  setup_all do
    {:ok, apps} = Application.ensure_all_started(:omg_status)

    on_exit(fn ->
      apps |> Enum.reverse() |> Enum.each(&Application.stop/1)
    end)

    :ok
  end

  setup do
    {:ok, alarm} = __MODULE__.Alarm.start(self())
    stall_threshold_blocks = 10
    check_interval_ms = 10

    {:ok, monitor} =
      SubmissionMonitor.start_link(
        alarm_module: __MODULE__.Alarm,
        event_bus_module: __MODULE__.BusMock,
        stall_threshold_blocks: stall_threshold_blocks,
        check_interval_ms: check_interval_ms
      )

    :ok =
      on_exit(fn ->
        _ = Process.exit(alarm, :test_cleanup)
        _ = Process.exit(monitor, :test_cleanup)
        _ = Process.sleep(10)
      end)

    {:ok,
     %{
       alarm: alarm,
       monitor: monitor,
       stall_threshold_blocks: stall_threshold_blocks,
       check_interval_ms: check_interval_ms
     }}
  end

  test "does not raise :block_submit_stalled alarm when block is below stall threshold", context do
    capture_log(fn ->
      # Inform the monitor of a pending block
      _ = send(context.monitor, {:internal_event_bus, :block_submitting, 1000})

      # Push the height just below the stalling height
      _ = send(context.monitor, {:internal_event_bus, :ethereum_new_height, context.stall_threshold_blocks - 1})

      # Wait for 10x the check interval to make sure the alarm really does not get raised.
      refute_receive(:got_raise_alarm, context.check_interval_ms * 10)
    end)
  end

  test "does not raise :block_submit_stalled alarm when the submitting block is below the last mined block", context do
    capture_log(fn ->
      # Inform the monitor of a mined block
      _ = send(context.monitor, {:internal_event_bus, :block_submitted, 2000})

      # Inform the monitor of a pending block lower than the mined block
      _ = send(context.monitor, {:internal_event_bus, :block_submitting, 1000})

      # Push the height to the stalling height
      _ = send(context.monitor, {:internal_event_bus, :ethereum_new_height, context.stall_threshold_blocks})

      # Wait for 10x the check interval to make sure the alarm really does not get raised.
      refute_receive(:got_raise_alarm, context.check_interval_ms * 10)
    end)
  end

  test "raises :block_submit_stalled alarm when blocks is at stall threshold", context do
    capture_log(fn ->
      # Inform the monitor of a pending block
      _ = send(context.monitor, {:internal_event_bus, :block_submitting, 1000})

      # Push the height to the stalling height
      _ = send(context.monitor, {:internal_event_bus, :ethereum_new_height, context.stall_threshold_blocks})

      assert_receive(:got_raise_alarm)
    end)
  end

  test "raises :block_submit_stalled alarm when blocks is above stall threshold", context do
    capture_log(fn ->
      # Inform the monitor of a pending block
      _ = send(context.monitor, {:internal_event_bus, :block_submitting, 1000})

      # Push the height pass the stalling height
      _ = send(context.monitor, {:internal_event_bus, :ethereum_new_height, context.stall_threshold_blocks + 1})

      assert_receive(:got_raise_alarm)
    end)
  end

  test "does not raise :block_submit_stalled alarm when it is already raised", context do
    # Set the monitor in a raised state
    :sys.replace_state(context.monitor, fn state -> %{state | alarm_raised: true} end)

    capture_log(fn ->
      # Inform the monitor of a pending block
      _ = send(context.monitor, {:internal_event_bus, :block_submitting, 1000})

      # Push the height pass the stalling height
      _ = send(context.monitor, {:internal_event_bus, :ethereum_new_height, context.stall_threshold_blocks})

      # Wait for 10x the check interval to make sure it really does not get raised again.
      refute_receive(:got_raise_alarm, context.check_interval_ms * 10)
    end)
  end

  test "clears :block_submit_stalled alarm when the stalled block no longer stalls", context do
    # Set the monitor in a raised state
    :sys.replace_state(context.monitor, fn state -> %{state | alarm_raised: true} end)

    capture_log(fn ->
      # Inform the monitor of a pending block
      _ = send(context.monitor, {:internal_event_bus, :block_submitting, 1000})

      # Push the height pass the stalling height
      _ = send(context.monitor, {:internal_event_bus, :ethereum_new_height, context.stall_threshold_blocks})

      # Now we inform the monitor that block #1000 is submitted
      _ = send(context.monitor, {:internal_event_bus, :block_submitted, 1000})

      # Expecting the alarm to be cleared
      assert_receive(:got_clear_alarm)
    end)
  end

  test "does not clear :block_submit_stalled alarm when some but not all stalled blocks got submitted", context do
    # Set the monitor in a raised state
    :sys.replace_state(context.monitor, fn state -> %{state | alarm_raised: true} end)

    capture_log(fn ->
      # Inform the monitor of two pending blocks
      _ = send(context.monitor, {:internal_event_bus, :block_submitting, 1000})
      _ = send(context.monitor, {:internal_event_bus, :block_submitting, 2000})

      # Push the height pass the stalling height
      _ = send(context.monitor, {:internal_event_bus, :ethereum_new_height, context.stall_threshold_blocks})

      # Now we inform the monitor that block #1000 is submitted, leaving #2000 still stalled
      _ = send(context.monitor, {:internal_event_bus, :block_submitted, 1000})

      # Because #2000 is still stalled, the alarm must not be cleared.
      # Wait for 10x the check interval to make sure it really does not get cleared.
      refute_receive(:got_clear_alarm, context.check_interval_ms * 10)
    end)
  end

  defmodule Alarm do
    @moduledoc """
    Mocks `OMG.Status.Alert.Alarm` so we can observe it for test assertions.
    """
    use GenServer

    def start(listener) do
      GenServer.start(__MODULE__, [listener], name: __MODULE__)
    end

    def init([listener]) do
      {:ok, %{listener: listener}}
    end

    def block_submit_stalled(reporter) do
      {:block_submit_stalled, %{node: Node.self(), reporter: reporter}}
    end

    def set({:block_submit_stalled, _details}) do
      GenServer.call(__MODULE__, :got_raise_alarm)
    end

    def clear({:block_submit_stalled, _details}) do
      GenServer.call(__MODULE__, :got_clear_alarm)
    end

    def handle_call(:got_raise_alarm, _, state) do
      {:reply, send(state.listener, :got_raise_alarm), state}
    end

    def handle_call(:got_clear_alarm, _, state) do
      {:reply, send(state.listener, :got_clear_alarm), state}
    end
  end

  defmodule BusMock do
    def subscribe(_, _) do
      :ok
    end
  end
end

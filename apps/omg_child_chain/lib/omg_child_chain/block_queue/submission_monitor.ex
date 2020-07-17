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

defmodule OMG.ChildChain.BlockQueue.SubmissionMonitor do
  @moduledoc """
  Listens to block events and raises :block_submit_stalled alarm when a pending block
  doesn't get successfully submitted within the specified time threshold.
  """
  use GenServer
  require Logger

  defstruct pending_blocks: [],
            root_chain_height: 0,
            stall_threshold_blocks: 4,
            alarm_module: nil,
            alarm_raised: false

  @typep blknum() :: pos_integer()
  @typep pending_block() :: {blknum :: blknum(), first_submit_height :: pos_integer()}

  @type t() :: %__MODULE__{
          pending_blocks: [pending_block()],
          root_chain_height: non_neg_integer(),
          stall_threshold_blocks: pos_integer(),
          alarm_module: module(),
          alarm_raised: boolean()
        }

  #
  # GenServer APIs
  #

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  #
  # GenServer behaviors
  #

  def init(opts) do
    _ = Logger.info("Starting #{__MODULE__}")
    _ = install_alarm_handler()
    event_bus = Keyword.fetch!(opts, :event_bus_module)
    check_interval_ms = Keyword.fetch!(opts, :check_interval_ms)

    state = %__MODULE__{
      pending_blocks: [],
      stall_threshold_blocks: Keyword.fetch!(opts, :stall_threshold_blocks),
      alarm_module: Keyword.fetch!(opts, :alarm_module),
      alarm_raised: false
    }

    :ok = event_bus.subscribe({:child_chain, "blocks"}, link: true)
    :ok = event_bus.subscribe({:root_chain, "ethereum_new_height"}, link: true)

    {:ok, _} = :timer.send_interval(check_interval_ms, self(), :check_stall)
    {:ok, state}
  end

  def handle_info(:check_stall, state) do
    stalled_blocks =
      Enum.filter(state.pending_blocks, fn {_blknum, first_submit_height} ->
        state.root_chain_height - first_submit_height >= state.stall_threshold_blocks
      end)

    _ = :telemetry.execute([:blocks_stalled, __MODULE__], %{blocks: stalled_blocks})
    _ = log_stalled_blocks(stalled_blocks, state.root_chain_height)
    _ = trigger_alarm(state.alarm_module, state.alarm_raised, stalled_blocks)

    {:noreply, state}
  end

  # Keeps track of the latest root chain height
  def handle_info({:internal_event_bus, :ethereum_new_height, new_height}, state) do
    {:noreply, %{state | root_chain_height: new_height}}
  end

  # Listens for a block being submitted and add it to monitoring if it hasn't been tracked
  def handle_info({:internal_event_bus, :block_submitting, blknum}, state) do
    pending_blocks = add_new_blknum(state.pending_blocks, blknum, state.root_chain_height)
    {:noreply, %{state | pending_blocks: pending_blocks}}
  end

  # Listens for a block that got submitted and drop it from monitoring
  def handle_info({:internal_event_bus, :block_submitted, blknum}, state) do
    pending_blocks = remove_blknum(state.pending_blocks, blknum)
    {:noreply, %{state | pending_blocks: pending_blocks}}
  end

  # Ignore unrelated events
  def handle_info({:internal_event_bus, :enqueue_block, _}, state) do
    {:noreply, state}
  end

  #
  # Handle incoming alarms
  #
  # These functions are called by the AlarmHandler so that this monitor process can update
  # its internal state according to the raised alarms.
  #
  def handle_cast({:set_alarm, :block_submit_stalled}, state) do
    {:noreply, %{state | alarm_raised: true}}
  end

  def handle_cast({:clear_alarm, :block_submit_stalled}, state) do
    {:noreply, %{state | alarm_raised: false}}
  end

  #
  # Private functions
  #

  # Add the blknum to tracking only if it is not already tracked
  @spec add_new_blknum([{blknum(), any()}], blknum(), non_neg_integer()) :: [pending_block()]
  defp add_new_blknum(pending_blocks, blknum, root_chain_height) do
    case Enum.any?(pending_blocks, fn {pending_blknum, _} -> pending_blknum == blknum end) do
      true -> pending_blocks
      false -> [{blknum, root_chain_height} | pending_blocks]
    end
  end

  @spec remove_blknum([{blknum(), any()}], blknum()) :: [pending_block()]
  defp remove_blknum(pending_blocks, blknum) do
    Enum.reject(pending_blocks, fn {pending_blknum, _} -> pending_blknum == blknum end)
  end

  #
  # Alarms management
  #

  defp install_alarm_handler() do
    case Enum.member?(:gen_event.which_handlers(:alarm_handler), __MODULE__.AlarmHandler) do
      true -> :ok
      _ -> :alarm_handler.add_alarm_handler(__MODULE__.AlarmHandler)
    end
  end

  @spec trigger_alarm(module(), boolean(), [blknum()]) :: :ok
  defp trigger_alarm(_alarm_module, false, []), do: :ok

  defp trigger_alarm(alarm_module, false, _stalled_blocks) do
    alarm_module.set(alarm_module.block_submit_stalled(__MODULE__))
  end

  defp trigger_alarm(alarm_module, true, []) do
    alarm_module.clear(alarm_module.block_submit_stalled(__MODULE__))
  end

  defp trigger_alarm(_alarm_module, true, _stalled_blocks), do: :ok

  #
  # Logging
  #
  defp log_stalled_blocks([], _), do: :ok

  defp log_stalled_blocks(stalled_blocks, root_chain_height) do
    Logger.warn(
      "#{__MODULE__}: Stalled blocks: #{inspect(stalled_blocks)}. " <>
        "Current height: #{inspect(root_chain_height)}"
    )
  end
end

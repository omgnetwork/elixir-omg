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

defmodule LoadTest.Common.SenderManager do
  @moduledoc """
  Registry-kind module that creates and starts sender processes and waits until all are done
  """

  use GenServer

  require Logger

  def sender_stats(new_stats) do
    GenServer.cast(__MODULE__, {:stats, Map.put(new_stats, :timestamp, System.monotonic_time(:millisecond))})
  end

  def block_forming_time(blknum, total_ms) do
    GenServer.cast(__MODULE__, {:blkform, blknum, total_ms})
  end

  @doc """
  Starts the sender's manager process
  """
  @spec start_link_all_senders(pos_integer(), list(), pos_integer(), keyword()) :: pid
  def start_link_all_senders(ntx_to_send, utxos, fee_amount, opts) do
    {:ok, mypid} = GenServer.start_link(__MODULE__, {ntx_to_send, utxos, fee_amount, opts}, name: __MODULE__)
    mypid
  end

  @doc """
  Starts sender processes
  """
  @spec init({pos_integer(), list(), pos_integer(), keyword()}) :: {:ok, map()}
  def init({ntx_to_send, utxos, fee_amount, opts}) do
    Process.flag(:trap_exit, true)
    _ = Logger.debug("init called with utxos: #{inspect(length(utxos))}, ntx_to_send: #{inspect(ntx_to_send)}")

    senders =
      utxos
      |> Enum.with_index(1)
      |> Enum.map(fn {utxo, seqnum} ->
        {:ok, pid} = LoadTest.Common.SenderServer.start_link({seqnum, utxo, ntx_to_send, fee_amount, opts})
        {seqnum, pid}
      end)

    initial_blknums =
      Enum.map(utxos, fn %{utxo_pos: utxo_pos} ->
        {:ok, %ExPlasma.Utxo{blknum: blknum}} = ExPlasma.Utxo.new(utxo_pos)
        blknum
      end)

    {:ok,
     %{
       senders: senders,
       fee_amount: fee_amount,
       events: [],
       block_times: [],
       goal: ntx_to_send,
       start_time: System.monotonic_time(:millisecond),
       destdir: opts[:destdir],
       initial_blknums: initial_blknums
     }}
  end

  @doc """
  Handles the trapped exit call and writes collected statistics to the file.
  Removes sender process which has done sending from a registry.
  If it is the last sender then writes stats and tears down sender manager

  Any unexpected child reportind :EXIT should result in a crash
  """
  def handle_info({:EXIT, from_pid, _reason}, %{senders: [{_last_seqnum, from_pid} = last_sender]} = state) do
    _ = Logger.info("Senders are all done, last sender: #{inspect(last_sender)}. Stopping manager")
    write_stats(state)
    {:stop, :normal, state}
  end

  def handle_info({:EXIT, from_pid, reason}, %{senders: senders} = state) do
    case Enum.find(senders, fn {_seqnum, pid} -> pid == from_pid end) do
      nil ->
        {:stop, {:unknown_child_exited, from_pid, reason}, state}

      {_done_seqnum, done_pid} = done_sender ->
        remaining_senders = Enum.filter(senders, fn {_seqnum, pid} -> pid != done_pid end)
        _ = Logger.info("Sender #{inspect(done_sender)} done. Manager continues...")
        {:noreply, %{state | senders: remaining_senders}}
    end
  end

  def handle_info({:EXIT, _from, reason}, state) do
    write_stats(state)
    _ = Logger.info(" +++ Manager Exiting (reason: #{inspect(reason)})... +++")
    {:stop, reason, state}
  end

  @doc """
  Register performance statistics received from senders processes.
  """
  @spec handle_cast({:stats, event :: tuple()}, state :: map()) :: {:noreply, map()}
  def handle_cast({:stats, event}, state) do
    {:noreply, %{state | events: [event | state.events]}}
  end

  @doc """
  Register block forming time received from the `OMG.Performance.BlockCreator` process.
  """
  @spec handle_cast({:blkform, blknum :: integer, total_ms :: pos_integer()}, state :: map()) :: {:noreply, map()}
  def handle_cast({:blkform, blknum, total_ms}, state) do
    {:noreply, %{state | block_times: [{blknum, total_ms} | state.block_times]}}
  end

  # Collects statistics regarding tx submittion and block forming.
  # Returns array of tuples, each tuple contains four fields:
  # * {blknum,   total_txs_in_blk,   avg_txs_in_sec,   time_between_blocks_ms}
  defp analyze(%{events: events, start_time: start, initial_blknums: initial_blknums}) do
    events_by_blknum = Enum.group_by(events, & &1.blknum)

    # we don't want the initial blocks that end up in the events
    ordered_keys =
      (events_by_blknum
       |> Map.keys()
       |> Enum.sort()) -- initial_blknums

    {_, block_stats} =
      ordered_keys
      |> Enum.map(&Map.fetch!(events_by_blknum, &1))
      |> Enum.map(&collect_block/1)
      |> Enum.reduce({start, []}, &analyze_block/2)

    Enum.reverse(block_stats)
  end

  # Receives all events from Senders processes related to the same block and computes block's statistics.
  defp collect_block(array) do
    blknum = array |> hd |> Map.get(:blknum)
    tx_max_index = array |> Enum.map(& &1.txindex) |> Enum.max()
    block_formed_timestamp = array |> Enum.map(& &1.timestamp) |> Enum.min()

    {blknum, tx_max_index + 1, block_formed_timestamp}
  end

  # Reducer function, computes average tx submitted per second and timespan from previous block.
  defp analyze_block({blknum, txs_in_blk, block_formed_timestamp}, {start, list}) do
    span_ms = block_formed_timestamp - start

    {block_formed_timestamp,
     [
       %{
         blknum: blknum,
         txs: txs_in_blk,
         tps: txs_per_second(txs_in_blk, span_ms),
         span_ms: span_ms
       }
       | list
     ]}
  end

  defp txs_per_second(txs_count, interval_ms) when interval_ms == 0, do: txs_count
  defp txs_per_second(txs_count, interval_ms), do: Kernel.round(txs_count * 1000 / interval_ms)

  # handle termination
  # omg_performance is not part of the application deployment bundle. It's used only for testing.
  # sobelow_skip ["Traversal"]
  defp write_stats(%{destdir: destdir} = state) do
    destfile = Path.join(destdir, "perf_result_stats_#{:os.system_time(:seconds)}.json")

    stats = analyze(state)
    :ok = File.write(destfile, Jason.encode!(stats))
    _ = Logger.info("Performance statistics written to file: #{inspect(destfile)}")
    _ = Logger.info("Performance statistics: #{inspect(stats)}")
    :ok
  end
end

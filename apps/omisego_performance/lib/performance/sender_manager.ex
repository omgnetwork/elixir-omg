defmodule OmiseGO.Performance.SenderManager do
  @moduledoc """
  Registry-kind module to manage sender processes, helps to create and start senders and waits when all are done.
  """

  use GenServer
  use OmiseGO.API.LoggerExt

  @initial_blknum 1000

  def sender_stats(new_stats) do
    GenServer.cast(__MODULE__, {:stats, Map.put(new_stats, :timestamp, System.monotonic_time(:millisecond))})
  end

  def block_forming_time(blknum, total_ms) do
    GenServer.cast(__MODULE__, {:blkform, blknum, total_ms})
  end

  @doc """
  Starts the sender's manager process
  """
  @spec start_link_all_senders(ntx_to_send :: integer, nusers :: integer, opt :: map) :: pid
  def start_link_all_senders(ntx_to_send, nusers, %{destdir: destdir} = _opt) do
    {:ok, mypid} = GenServer.start_link(__MODULE__, {ntx_to_send, nusers, destdir}, name: __MODULE__)
    mypid
  end

  @doc """
  Starts sender processes and reschedule check whether they are done.
  """
  @spec init({integer, integer, binary}) :: {:ok, map()}
  def init({ntx_to_send, nusers, destdir}) do
    Process.flag(:trap_exit, true)
    _ = Logger.debug(fn -> "init called with #{inspect(nusers)} users, each to send #{inspect(ntx_to_send)}" end)

    senders =
      1..nusers
      |> Enum.map(fn seqnum ->
        {:ok, pid} = OmiseGO.Performance.SenderServer.start_link({seqnum, ntx_to_send})
        {seqnum, pid}
      end)

    {:ok,
     %{
       senders: senders,
       events: [],
       block_times: [],
       goal: ntx_to_send,
       start_time: System.monotonic_time(:millisecond),
       destdir: destdir
     }}
  end

  @doc """
  Handles the trapped exit call and writes collected statistics to the file.
  Removes sender process which has done sending from a registry.
  If it is the last sender then writes stats and tears down sender manager

  Any unexpected child reportind :EXIT should result in a crash
  """
  def handle_info({:EXIT, from_pid, _reason}, %{senders: [{_last_seqnum, from_pid} = last_sender]} = state) do
    _ = Logger.info(fn -> "[SM]: Senders are all done, last sender: #{inspect(last_sender)}. Stopping manager" end)
    write_stats(state)
    {:stop, :normal, state}
  end

  def handle_info({:EXIT, from_pid, reason}, %{senders: senders} = state) do
    case Enum.find(senders, fn {_seqnum, pid} -> pid == from_pid end) do
      nil ->
        {:stop, {:unknown_child_exited, from_pid, reason}, state}

      {_done_seqnum, done_pid} = done_sender ->
        remaining_senders = Enum.filter(senders, fn {_seqnum, pid} -> pid != done_pid end)
        _ = Logger.info(fn -> "[SM]: Sender #{inspect(done_sender)} done. Manager continues..." end)
        {:noreply, %{state | senders: remaining_senders}}
    end
  end

  def handle_info({:EXIT, _from, reason}, state) do
    write_stats(state)
    _ = Logger.info(fn -> "[SM] +++ Manager Exiting (reason: #{inspect(reason)})... +++" end)
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
  Register block forming time received from the BlockCreator process.
  """
  @spec handle_cast({:blkform, blknum :: integer, total_ms :: pos_integer()}, state :: map()) :: {:noreply, map()}
  def handle_cast({:blkform, blknum, total_ms}, state) do
    {:noreply, %{state | block_times: [{blknum, total_ms} | state.block_times]}}
  end

  # Collects statistics regarding tx submittion and block forming.
  # Returns array of tuples, each tuple contains four fields:
  # * {blknum,   total_txs_in_blk,   avg_txs_in_sec,   time_between_blocks_ms}
  defp analyze(%{events: events, start_time: start}) do
    events_by_blknum = events |> Enum.group_by(& &1.blknum)

    ordered_keys =
      events_by_blknum
      |> Map.keys()
      |> Enum.sort()
      # we don't want the deposit blocks that end up in the events
      |> Enum.filter(fn blknum -> blknum >= @initial_blknum end)

    {_, block_stats} =
      ordered_keys
      |> Enum.map(&Map.fetch!(events_by_blknum, &1))
      |> Enum.map(&collect_block/1)
      |> Enum.reduce({start, []}, &analyze_block/2)

    block_stats |> Enum.reverse()
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

  defp txs_per_second(txs_count, interval_ms), do: Float.round(txs_count * 1000 / interval_ms, 2)

  # handle termination
  defp write_stats(%{destdir: destdir} = state) do
    destfile = Path.join(destdir, "perf_result_#{:os.system_time(:seconds)}_stats.json")

    stats = analyze(state)
    :ok = File.write(destfile, Poison.encode!(stats))
    _ = Logger.info(fn -> "Performance statistics written to file: #{inspect(destfile)}" end)
    :ok
  end
end

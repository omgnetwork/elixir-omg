defmodule OmiseGO.Performance.SenderManager do
  @moduledoc """
  Registry-kind module to manage sender processes, helps to create and start senders and waits when all are done.
  """

  require Logger
  use GenServer

  @initial_blknum 1000
  @check_senders_done_every_ms 500

  @doc """
  Removes sender process which has done sending from a registry.
  """
  def sender_completed(seqnum) do
    GenServer.cast(__MODULE__, {:done, seqnum})
  end

  def sender_stats(seqnum, blknum, txindex, txs_left) do
    GenServer.cast(__MODULE__, {:stats, {seqnum, blknum, txindex, txs_left, System.monotonic_time(:millisecond)}})
  end

  def block_forming_time(blknum, total_ms) do
    GenServer.cast(__MODULE__, {:blkform, blknum, total_ms})
  end

  @doc """
  Starts the sender's manager process
  """
  @spec start(ntx_to_send :: integer, nusers :: integer) :: pid
  def start(ntx_to_send, nusers) do
    {:ok, mypid} = GenServer.start_link(__MODULE__, {ntx_to_send, nusers}, name: __MODULE__)
    mypid
  end

  @doc """
  Starts sender processes and reschedule check whether they are done.
  """
  @spec init(tuple) :: map()
  def init({ntx_to_send, nusers}) do
    Process.flag(:trap_exit, true)
    Logger.debug(fn -> "[SM] +++ init/1 called with #{nusers} users, each to send #{ntx_to_send} +++" end)

    senders = 1..nusers
            |> Enum.map(fn seqnum ->
                {:ok, pid} = OmiseGO.Performance.SenderServer.start_link({seqnum, ntx_to_send})
                {seqnum, pid}
            end)

    reschedule_check()
    {:ok, %{
      senders: senders,
      events: [],
      block_times: [],
      goal: ntx_to_send,
      start_time: System.monotonic_time(:millisecond)
    }}
  end

  @doc """
  Handles the trapped exit call and writes collected statistics to the file.
  """
  def handle_info({:EXIT, _from, reason}, state) do
    write_stats(state)
    IO.puts("[SM] +++ Stoping (reason: #{inspect reason})... +++")
    {:stop, reason, state}
  end

  @doc """
  Checks whether registry has sender proceses registered
  """
  @spec handle_info(:check, state :: pid | atom)
  :: {:noreply, newstate :: pid | atom} | {:stop, :shutdown, state :: pid | atom}
  def handle_info(:check, %{senders: senders} = state) when length(senders) == 0 do
    {:stop, :normal, state}
  end

  def handle_info(:check, state) do
    Logger.debug(fn -> "[SM]: Senders are alive" end)
    reschedule_check()
    {:noreply, state}
  end

  @doc """
  Removes sender process which has done sending from a registry.
  """
  @spec handle_cast({:done, seqnum :: integer}, state :: map()) :: {:noreply, map()}
  def handle_cast({:done, seqnum}, %{senders: senders} = state) do
    {:noreply, %{state | senders: Enum.reject(senders, &(match?({^seqnum, _}, &1)))}}
  end

  @doc """
  Register performance statistics received from senders processes.
  """
  def handle_cast({:stats, event}, state) do
    {:noreply, %{state | events: [event | state.events]}}
  end

  @doc """
  Register block forming time received from the BlockCreator process.
  """
  def handle_cast({:blkform, blknum, total_ms}, state) do
    {:noreply, %{state | block_times: [{blknum, total_ms} | state.block_times]}}
  end

  # Sends :check message to itself in @check_senders_done_every_ms milliseconds.
  # Message will be processed by module's :handle_info function.
  @spec reschedule_check() :: :ok
  defp reschedule_check, do: Process.send_after(self(), :check, @check_senders_done_every_ms)


  defp analyze(%{events: events, start_time: start}) do
    events_by_blknum = events |> Enum.group_by(&(elem(&1, 1)))

    ordered_keys = @initial_blknum
      |> Stream.iterate(&(&1 + @initial_blknum))
      |> Enum.take_while(&(Map.has_key?(events_by_blknum, &1)))

    {_, block_stats} = ordered_keys
      |> Enum.map(&(Map.fetch!(events_by_blknum, &1)))
      |> Enum.map(&collect_block/1)
      |> Enum.reduce_while({start, []}, &analyze_block/2)

    block_stats |> Enum.reverse()
  end

  # Receives all events from Senders processes related to the same block and computes block's statistics.
  defp collect_block(array) do
    blknum = array |> hd |> elem(1)
    tx_max_index = array |> Enum.map(&(elem(&1, 2))) |> Enum.max()
    time = array |> Enum.map(&(elem(&1, 4))) |> Enum.min()

    {blknum, tx_max_index + 1, time}
  end

  # Reducer function, computes average tx submitted per second and timespan from previous block.
  defp analyze_block({blknum, txs_in_blk, time}, {start, list}) do
    span_ms = time - start
    if span_ms > 1000 do
      {:cont,
        {time,
          [{
            blknum,
            txs_in_blk,
            avg_txs_in_second(txs_in_blk, span_ms),
            span_ms
          } | list]
        }
      }
    else
      {:halt, {start, list}}
    end
  end

  defp avg_txs_in_second(txs_count, interval_ms), do:
    txs_count * 1000 / interval_ms |> Float.round(2)

  # handle termination
  def write_stats(state) do
    destdir = Application.get_env(:omisego_performance, :analysis_output_dir)
    {testid, ntx_to_send, nusers} = OmiseGO.Performance.Runner.get_test_env()
    destfile = "#{destdir}/perftest-tx#{ntx_to_send}-u#{nusers}-#{testid}.statistics"

    data = "Block forming times:\n#{inspect(state.block_times,limit: :infinity, pretty: true)}\n"
    stats = analyze(state)
    data = data <> "\nPerformance statistics:\n#{inspect(stats,limit: :infinity, pretty: true)}\n"
    File.write(destfile, data)
    IO.puts "Performance statistics written to file: #{destfile}"
    :ok
  end
end

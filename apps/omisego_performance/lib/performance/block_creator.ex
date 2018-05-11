defmodule OmiseGO.Performance.BlockCreator do
  @moduledoc """
  Module simulates forming new block on childchain at specified time intervals
  """

  require Logger
  use GenServer

  @request_block_creation_every_ms 2000
  @initial_block_number 1000

  @doc """
  Starts the process. Only one process of BlockCreator can be started.
  """
  def start_link do
    GenServer.start_link(__MODULE__, @initial_block_number, name: __MODULE__)
  end

  @doc """
  Initializes the process with @initial_block_number stored in the process state.
  Reschedules call to itself wchich starts block forming loop.
  """
  @spec init(integer) :: {:ok, integer}
  def init(blknum) do
    _ = Logger.debug(fn -> "[BC] +++ init/1 called with args: '#{inspect(blknum)}' +++" end)
    reschedule_task()
    {:ok, blknum}
  end

  @doc """
  Forms new block, reports time consumed by API response and reschedule next call
  in @request_block_creation_every_ms milliseconds.
  """
  def handle_info(:do, blknum) do
    newblknum = blknum + 1000
    _ = Logger.debug(fn -> "[BC]: Forming block #{blknum}, next #{newblknum}" end)

    start = System.monotonic_time(:millisecond)
    OmiseGO.API.State.form_block(blknum, newblknum)
    stop = System.monotonic_time(:millisecond)
    OmiseGO.Performance.SenderManager.block_forming_time(blknum, stop - start)

    reschedule_task()
    {:noreply, newblknum}
  end

  defp reschedule_task do
    Process.send_after(self(), :do, @request_block_creation_every_ms)
  end
end

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
    child_block_interval = 1000

    OmiseGO.API.State.form_block(child_block_interval)
    OmiseGO.Performance.SenderManager.block_forming_time(blknum, 0)

    reschedule_task()
    {:noreply, blknum + child_block_interval}
  end

  defp reschedule_task do
    Process.send_after(self(), :do, @request_block_creation_every_ms)
  end
end

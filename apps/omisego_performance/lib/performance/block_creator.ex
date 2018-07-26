defmodule OmiseGO.Performance.BlockCreator do
  @moduledoc """
  Module simulates forming new block on childchain at specified time intervals
  """

  use GenServer
  use OmiseGO.API.LoggerExt

  @initial_block_number 1000

  @doc """
  Starts the process. Only one process of BlockCreator can be started.
  """
  def start_link(block_every_ms) do
    GenServer.start_link(__MODULE__, {@initial_block_number, block_every_ms}, name: __MODULE__)
  end

  @doc """
  Initializes the process with @initial_block_number stored in the process state.
  Reschedules call to itself wchich starts block forming loop.
  """
  @spec init({integer, integer}) :: {:ok, {integer, integer}}
  def init({blknum, block_every_ms}) do
    _ = Logger.debug(fn -> "init called with args: '#{inspect(blknum)}'" end)
    reschedule_task(block_every_ms)
    {:ok, {blknum, block_every_ms}}
  end

  @doc """
  Forms new block, reports time consumed by API response and reschedule next call
  in @request_block_creation_every_ms milliseconds.
  """
  def handle_info(:do, {blknum, block_every_ms}) do
    child_block_interval = 1000

    OmiseGO.API.State.form_block(child_block_interval)
    OmiseGO.Performance.SenderManager.block_forming_time(blknum, 0)

    reschedule_task(block_every_ms)
    {:noreply, {blknum + child_block_interval, block_every_ms}}
  end

  defp reschedule_task(block_every_ms) do
    Process.send_after(self(), :do, block_every_ms)
  end
end

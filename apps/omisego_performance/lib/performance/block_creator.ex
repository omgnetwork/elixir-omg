defmodule OmiseGO.Performance.BlockCreator do
  @moduledoc """
  Module simulates forming new block on childchain on specified time intervals
  """

  require Logger
  use GenServer

  @request_block_creation_every_ms 9000
  @initial_block_number 1000

  def start_link do
    GenServer.start_link(__MODULE__, @initial_block_number, name: __MODULE__)
  end

  def init(args) do
    Logger.debug(fn -> "[BC] +++ init/1 called with args: '#{inspect args}' +++" end)
    reschedule_task()
    {:ok, args}
  end

  def handle_info(:do, blknum) do
    newblknum = blknum + 1000
    Logger.debug(fn -> "[BC]: Forming block #{blknum}, next #{newblknum}" end)
    OmiseGO.API.State.form_block(blknum, newblknum)

    reschedule_task()
    {:noreply, newblknum}
  end

  defp reschedule_task do
    Process.send_after(self(), :do, @request_block_creation_every_ms)
  end
end

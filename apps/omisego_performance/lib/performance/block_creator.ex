defmodule OmiseGO.Performance.BlockCreator do
  @moduledoc """
  Module simulates forming new block on childchain on specified time intervals
  """

  require Logger
  use GenServer

  @request_block_creation_every_ms 2500

  def start_link do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(args) do
    Logger.debug(fn -> "[BC] +++ init/1 called with args: '#{inspect args}' +++" end)
    Process.send_after(self(), :do, @request_block_creation_every_ms)
    {:ok, args}
  end

  def handle_info(:do, state) do
    Logger.debug(fn -> "[BC]: Forming new block {which?}" end)
    OmiseGO.API.State.form_block(1000, 2000)
    {:noreply, state}
  end
end

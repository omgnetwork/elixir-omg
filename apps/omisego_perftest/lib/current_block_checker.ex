defmodule CurrentBlockChecker do
  @moduledoc """
  Checks the current block number in the chain an broadcast it to the senders.
  """

  use GenServer

  @init_block_num  1000
  @check_for_new_blocks_every_ms 2250

  @doc """
  Starts the server.
  """
  @spec start_link() :: {:ok, pid}
  def start_link() do
    state = {@init_block_num, }
    GenServer.start_link(__MODULE__, state, name: CurrentBlockChecker)
  end

  @doc """
  Initializes the CurrentBlockChecker process and schedules handle_info call.
  """
  @spec init(init_state :: tuple) :: {:ok, state :: tuple}
  def init(args = {blocknum}) do
    IO.puts "CurrentBlockChecker - init/1 called with args: '#{blocknum}'"
    send(self(), {:do})

    {:ok, args}
  end

  @doc """
  Checks the current block number and broadcast it to the senders.
  When any sender left schedules call to itself in @check_for_new_blocks_every_ms miliseconds,
  stops otherwise.
  """
  @spec handle_info({:do}, state :: tuple) :: {:noreply, new_state :: tuple} | {:stop, :shutdown, nil}
  def handle_info({:do}, {blocknum}) do
    senders = Registry.lookup(OmiseGO.PerfTest.Registry, :sender)

    unless Enum.empty?(senders) do
      blocknum = get_current_block_number(blocknum)
      broadcast_new_block(senders, blocknum)

      {:noreply, {blocknum}}
    else
      IO.puts "CurrentBlockChecker - Stoping..."
      {:stop, :shutdown, nil}
    end
  end

  @doc """
  Gets the current block number from the blockchain server.
  """
  #FIXME: Add spec - CurrentBlockChecker.get_current_block_number()
  def get_current_block_number(blocknum) do
    blocknum + 1000
  end

  @doc """
  Broadcasts the current block number to senders.
  """
  #FIXME: Add spec - CurrentBlockChecker.broadcast_new_block()
  def broadcast_new_block(senders, blocknum) do
    IO.puts "CurrentBlockChecker - sending new block number: #{blocknum} to #{Enum.count(senders)} senders"
    Registry.dispatch(OmiseGO.PerfTest.Registry, :sender, fn senders ->
      Enum.each(senders, fn {pid, _} -> GenServer.cast(pid, {:update, blocknum}) end)
    end)

    Process.send_after(self(), {:do}, @check_for_new_blocks_every_ms)
  end
end

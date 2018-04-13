defmodule CurrentBlockChecker do
  @moduledoc """
  Checks the current block number in a chain an broadcast it to the senders
  """

  use GenServer

  @init_block_num  1000

  @doc """
  Starts the server
  """
  def start_link(block_num \\ nil) do
    GenServer.start_link(__MODULE__, block_num || @init_block_num, name: CurrentBlockChecker)
  end

  def init(args) do
    IO.puts "CurrentBlockChecker - init/1 called with args: '#{args}'"
    {:ok, args}
  end
end

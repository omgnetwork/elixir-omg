defmodule SenderServer do
  @moduledoc """
  The SenderServer process synchronously sends requested number of transactions to the blockchain server.
  """

  use GenServer

  @doc """
  Starts the server.
  """
  @spec start_link({senderid :: integer, nrequests :: integer, init_blocknum :: integer}) :: {:ok, pid}
  def start_link(args) do
    GenServer.start_link(__MODULE__, args)
  end

  @doc """
  Initializes the SenderServer process, register it into the Registry and schedules handle_info call.
  """
  @spec init({senderid :: integer, nrequests :: integer, init_blocknum :: integer}) :: {:ok, init_state :: tuple}
  def init({senderid, nrequests, init_blocknum}) do
    IO.puts "SenderServer[#{senderid}] - init/1 called with requests: '#{nrequests}'"
    Registry.register(OmiseGO.PerfTest.Registry, :sender, "Sender: #{senderid}")
    send(self(), {:do})
    {:ok, {senderid, nrequests, init_blocknum}}
  end

  @doc """
  Submits translaction then schedules call to itself if any requests left.
  Otherwise unregisters from the Registry and stops.
  """
  @spec handle_info({:do}, state :: {senderid :: integer, nrequests :: integer, blocknum :: integer}) :: {:noreply, new_state :: tuple} | {:stop, :normal, nil}
  def handle_info({:do}, state) do
    submit_tx(state)

    {senderid, nrequests, _} = state
    if nrequests > 0 do
      send(self(), {:do})
      {:noreply, put_elem(state, 1, nrequests-1)}
    else
      Registry.unregister(OmiseGO.PerfTest.Registry, :sender)
      IO.puts "SenderServer[#{senderid}] - Stoping..."
      {:stop, :normal, nil}
    end
  end

  @doc """
  Updates state with current block number sent by CurrentBlockChecker process.
  """
  @spec handle_cast({:update, blocknum :: integer}, state :: tuple) :: {:no_reply, new_state :: tuple}
  def handle_cast({:update, blocknum}, state) do
    {:noreply, put_elem(state, 2, blocknum)}
  end

  @doc """
  Submits new transaction to the blockchain server.
  """
  #FIXME: Add spec - SenderServer.submit_tx()
  def submit_tx({senderid, nrequests, blocknum}) do
    IO.puts "[#{senderid}] Sending requests #{nrequests} to block #{blocknum}"

    # simulating time elapsed for tx send
    Process.sleep(1000 + Enum.random([-500, -250, 0, 500, 750, 1250]))
  end
end

defmodule SenderServer do
  @moduledoc """
  Sender synchronously sends transaction to chain server
  """

  use GenServer

  @doc """
  Starts the server
  """
  def start_link(nrequests) do
    GenServer.start_link(__MODULE__, nrequests)
  end

  def init(args) do
    IO.puts "SenderServer - init/1 called with args: '#{args}'"
    send(self(), {:do})
    {:ok, args}
  end

  def handle_info({:do}, nrequests) do
    IO.puts "Sending requests - #{nrequests} downto 0"

    if nrequests > 0, do: send(self(), {:do})
    {:noreply, nrequests-1}
  end
end

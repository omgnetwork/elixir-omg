defmodule OmiseGOWatcher.Eventer do
  @moduledoc """
  Imperative shell for handling events
  """

  alias OmiseGO.JSONRPC
  alias OmiseGOWatcher.Eventer.Core
  alias OmiseGOWatcherWeb.Endpoint

  ### Client

  def start_link(_args) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def notify(event_triggers) do
    GenServer.cast(__MODULE__, {:notify, event_triggers})
  end

  ### Server

  use GenServer

  def init(:ok) do
    {:ok, nil}
  end

  def handle_cast({:notify, event_triggers}, state) do
    event_triggers
    |> Core.notify()
    |> Enum.each(fn {topic, event_name, event} ->
      :ok = Endpoint.broadcast!(topic, event_name, JSONRPC.Client.encode(event))
    end)

    {:noreply, state}
  end
end

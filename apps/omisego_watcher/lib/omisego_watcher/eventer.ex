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

  def emit_events(event_triggers) do
    GenServer.cast(__MODULE__, {:emit_events, event_triggers})
  end

  ### Server

  use GenServer

  def init(:ok) do
    {:ok, nil}
  end

  def handle_cast({:emit_events, event_triggers}, state) do
    event_triggers
    |> Core.prepare_events()
    |> Enum.each(fn {topic, event_name, event} ->
      :ok = Endpoint.broadcast!(topic, event_name, JSONRPC.Client.encode(event))
    end)

    {:noreply, state}
  end
end

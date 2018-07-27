defmodule OmiseGOWatcher.Eventer do
  @moduledoc """
  Imperative shell for handling events
  """

  alias OmiseGOWatcher.Eventer.Core
  alias OmiseGOWatcherWeb.Endpoint

  ### Client

  def start_link(_args) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def emit_events(event_triggers) do
    GenServer.cast(__MODULE__, {:emit_events, event_triggers})
  end

  def emit_event(event) do
    GenServer.cast(__MODULE__, {:emit_event, event})
  end

  ### Server

  use GenServer

  def init(:ok) do
    {:ok, nil}
  end

  def handle_cast({:emit_events, event_triggers}, state) do
    event_triggers
    |> Core.prepare_events()
    |> Enum.each(fn {topic, event_name, event} -> :ok = Endpoint.broadcast!(topic, event_name, event) end)

    {:noreply, state}
  end

  def handle_cast({:emit_event, nil}, state) do
    {:noreply, state}
  end

  def handle_cast({:emit_event, event_trigger}, state) do
    {topic, event_name, event} = Core.prepare_event(event_trigger)

    Endpoint.broadcast!(topic, event_name, event)

    {:noreply, state}
  end
end

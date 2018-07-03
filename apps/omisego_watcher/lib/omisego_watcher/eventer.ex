defmodule OmiseGOWatcher.Eventer do
  @moduledoc """
  Imperative shell for handling events
  """

  alias OmiseGOWatcher.Eventer.Core

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
    IO.inspect("Client notify handle_cast")
    IO.inspect(event_triggers)

    data =
      event_triggers
      |> Core.notify()

    # |> Enum.each(fn {notification, topic} -> :ok = PubSub.broadcast(:eventer, topic, notification) end)
    IO.inspect(data)
    {:noreply, state}
  end
end

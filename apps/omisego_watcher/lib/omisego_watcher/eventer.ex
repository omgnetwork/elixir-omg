defmodule OmiseGOWatcher.Eventer do
  @moduledoc """
  Imperative shell for handling events
  """

  alias OmiseGOWatcher.Eventer.Core
  alias Phoenix.PubSub

  @pubsub :eventer

  ### Client

  def notify(event_triggers) do
    GenServer.cast(__MODULE__, {:notify, event_triggers})
  end

  def subscribe(topic) when is_binary(topic) do
    case PubSub.subscribe(@pubsub, topic) do
      :ok -> :ok
      {:error, _message} -> :error
    end
  end

  def unsubscribe(topic) when is_binary(topic) do
    case PubSub.unsubscribe(@pubsub, topic) do
      :ok -> :ok
      {:error, _message} -> :error
    end
  end

  ### Server

  use GenServer

  def init(:ok) do
    {:ok, nil}
  end

  def handle_cast({:notify, event_triggers}, state) do
    event_triggers
    |> Core.notify()
    |> Enum.each(fn {notification, topic} -> :ok = PubSub.broadcast(:eventer, topic, notification) end)

    {:noreply, state}
  end
end

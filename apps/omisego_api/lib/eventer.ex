defmodule OmiseGO.API.Eventer do

  alias Phoenix.PubSub
  alias OmiseGO.API.Eventer.Core

  @pubsub :eventer

  ### Client

  def notify(event_triggers) do
    GenServer.cast(__MODULE__, {:notify, event_triggers})
  end

  def subscribe(topics) when is_list(topics) do
    subs = Enum.map(topics, &(PubSub.subscribe(@pubsub, &1)))
    subs
    |> Enum.reduce(:ok, fn (a, b) -> if b != :ok, do: :error, else: a end)
  end

  def unsubscribe(topics) when is_list(topics) do
    unsubs = Enum.map(topics, &(PubSub.unsubscribe(@pubsub, &1)))
    unsubs
    |> Enum.reduce(:ok, fn (a, b) -> if b != :ok, do: :error, else: a end)
  end

  ### Server

  use GenServer

  def init(:ok) do
    {:ok, nil}
  end

  def handle_cast({:notify, event_triggers}, state) do
    event_triggers
    |> Core.notify
    |> Enum.each(fn {notification, topic} -> PubSub.broadcast(:eventer, topic, notification) end)
    {:noreply, state}
  end

end

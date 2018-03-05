defmodule OmiseGO.API.Eventer do

  defmodule State do
    @type topic: binary()
    @type subscriber: binary()
    defstruct [subscriptions: BiMultiMap.new(), listeners: Map.new()]

    @type t :: %State{
      subscriptions: BiMultiMap.t(subscriber, topic),
      listeners: map(subscriber, pid)
    }
  end

  ### Client

  def notify(event_triggers) do
    messages = GenServer.cast(__MODULE__, {:notify, event_triggers})
    Enum.each(messages, fn msg -> send(msg.receiver, msg.body) end)
  end

  def subscribe({subscribed_address, topics}) when is_list(topics) do
    GenServer.call(__MODULE__, {:subscribe, {subscribed_address, topics}})
  end

  def unsubscribe(topics) when is_list(topics) do
    GenServer.call(__MODULE__, {:unsubscribe, topics})
  end

  ### Server

  use GenServer

  def init(:ok) do
    {:ok, %State{}}
  end

  def handle_cast({:notify, event_triggers}, state) do
    {notifications, state} = Core.notify(event_triggers, state)
    # Send notifications through ws
    {:noreply, state}
  end

  def handle_call({:subsribe, {subscriber_address, topics}}, from, state) do
    # handle monitoring pids (in case of dead websockets)
    state = Core.subscribe(from, subscriber_address, topics, state)
    {:reply, :ok, state}
  end

  def handle_call({:unsubscribe, topics}, from, state) do
    # handle monitoring pids (in case of dead websockets)
    state = Core.unsubscribe(from, topics, state)
    {:reply, :ok, state}
  end

  defmodule Core do

    @spec subscribe(pid, binary(), [binary()], State.t) :: State.t
    def subscribe(listener, subscriber_address, topics,
                  %State{subscriptions: subscriptions, listeners: listeners} = state) do
      listeners =
        if BiMultiMap.member?(listeners, subscriber_address) do
          listeners
        else
          BiMultiMap.put(listeners, listener, subscriber_address)
        end
      subscriptions =
        case BiMultiMap.get_values(subscriptions, subscriber_address) do
          [] -> BiMultiMap.put(subscriptions, subscriber_address, topics)
          subscribed_topics ->
            BiMultiMap.put(subscriptions, subscriber_address, Enum.uniq(subscribed_topics ++ topics))
        end
      %State{subscriptions: subscriptions, listeners: listeners}
    end

    @spec unsubscribe(pid(), State.t) :: State.t
    def unsubscribe(listener, %State{subscriptions: subscriptions, listeners: listeners} = state) do
      #consider topics you want to unsubsribe from
      case BiMultiMap.get_values(listeners, listener) do
        [] -> state
        [subscriber_address] ->
          listeners = BiMultiMap.delete_key(listeners, listener)
          subscribers = BiMultiMap.delete_key(subscribers, subscriber_address)
          %State{subscriptions: subscriptions, listeners: listeners}
      end
    end

    @spec notify(any(), State.t) :: {[{pid(), any()}], State.t}
    def notify(event_triggers, %State{listeners: listeners} = state) do
      # cycle through state.subscriptions and generate list of {listener, body} pairs
      notifications = Enum.map(event_trigger, &(get_subscriber_with_notification(&1)))
      notifications = Enum.flat_map(notifications,
                                    fn {subscriber, notification} ->
                                      listeners = BiMultiMap.get_values(listeners, subscriber)
                                      Enum.map(listeners, fn listener -> {listener, notification} end)
                                    end)
      {notifications, state}
    end

    @spec get_subscriber_with_notification(any()) :: {subscriber, any()}
    defp get_subscriber_with_notification(event_trigger)

  end
end

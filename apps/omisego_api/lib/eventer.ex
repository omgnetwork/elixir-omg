defmodule OmiseGO.API.Eventer do

  ### Client

  def notify(event_triggers) do
    messages = GenServer.cast(__MODULE__.Core, {:notify, event_triggers})
    Enum.each(messages, fn msg -> send(msg.receiver, msg.body) end)
  end

  def subscribe(args) do
    GenServer.call(__MODULE__.Core, {:subscribe, args})
  end

  ### Server

  def handle_call({:notify, event_triggers}, _from, state) do

  end

  defmodule Core do

    def notify(event_triggers, state) do
      # cycle through state.subscriptions and generate list of {receiver, body} pairs
      events = []
    end
  end
end

defmodule OmiseGO.API.Eventer do
  @moduledoc """
  soon to be filled out in Pawel's PR
  """

  ### Client

  def notify(event_triggers) do
    messages = GenServer.cast(__MODULE__.Core, {:notify, event_triggers})
    Enum.each(messages, fn msg -> send(msg.receiver, msg.body) end)
  end

  def subscribe(args) do
    GenServer.call(__MODULE__.Core, {:subscribe, args})
  end

  ### Server

  def handle_call({:notify, _event_triggers}, _from, _state) do

  end

  defmodule Core do
    @moduledoc """
    soon to be filled out in Pawel's PR
    """

    def notify(_event_triggers, _state) do
      # cycle through state.subscriptions and generate list of {receiver, body} pairs
      _events = []
    end
  end
end

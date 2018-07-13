defmodule OmiseGOWatcher.Eventer.Core do
  @moduledoc """
  Functional core of eventer
  """

  alias OmiseGO.API.State.Transaction
  alias OmiseGOWatcher.Eventer.Event

  @address_topic "address"
  @byzantine_topic "byzantine"

  @spec prepare_events(any()) :: list({binary(), binary(), Event.t()})
  def prepare_events(event_triggers) do
    Enum.flat_map(event_triggers, &get_events_with_topic(&1))
  end

  @spec prepare_event(Event.t()) :: {binary(), binary(), Event.t()}
  def prepare_event(event) do
    get_event_with_topic(event)
  end

  defp get_event_with_topic(%Event.BlockWithHolding{} = event) do
      {@byzantine_topic, Event.BlockWithHolding.name(), event}
  end

  defp get_events_with_topic(event_trigger) do
    address_received_events = get_address_received_events(event_trigger)
    address_received_events
  end

  defp get_address_received_events(
         %{
           tx: %Transaction.Recovered{raw_tx: %Transaction{newowner1: newowner1, newowner2: newowner2}}
         } = event_trigger
       ) do
    [newowner1, newowner2]
    |> Enum.filter(&Transaction.account_address?/1)
    |> Enum.map(&create_address_received_event(event_trigger, &1))
    |> Enum.uniq()
  end

  defp create_address_received_event(event_trigger, address) do
    encoded_address = "0x" <> Base.encode16(address, case: :lower)
    subtopic = create_subtopic(@address_topic, encoded_address)

    {subtopic, Event.AddressReceived.name(), struct(Event.AddressReceived, event_trigger)}
  end

  defp create_subtopic(main_topic, subtopic), do: main_topic <> ":" <> subtopic
end

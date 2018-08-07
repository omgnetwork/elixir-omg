defmodule OmiseGOWatcher.Eventer.Core do
  @moduledoc """
  Functional core of eventer
  """

  alias OmiseGO.API.Crypto
  alias OmiseGO.API.State.Transaction
  alias OmiseGOWatcher.Eventer.Event

  @transfer_topic "transfer"
  @byzantine_topic "byzantine"

  @spec prepare_events(any() | Event.t()) :: list({String.t(), String.t(), Event.t()})
  def prepare_events(event_triggers) do
    Enum.flat_map(event_triggers, &get_event_with_topic(&1))
  end

  defp get_event_with_topic(%Event.InvalidBlock{} = event) do
    [{@byzantine_topic, Event.InvalidBlock.name(), event}]
  end

  defp get_event_with_topic(%Event.BlockWithHolding{} = event) do
    [{@byzantine_topic, Event.BlockWithHolding.name(), event}]
  end

  defp get_event_with_topic(event_trigger) do
    get_address_received_events(event_trigger) ++ get_address_spent_events(event_trigger)
  end

  defp get_address_spent_events(
         %{
           tx: %Transaction.Recovered{
             spender1: spender1,
             spender2: spender2
           }
         } = event_trigger
       ) do
    [spender1, spender2]
    |> Enum.filter(&Transaction.account_address?/1)
    |> Enum.map(&create_address_spent_event(event_trigger, &1))
    |> Enum.uniq()
  end

  defp create_address_spent_event(event_trigger, address) do
    subtopic = create_transfer_subtopic(address)
    {subtopic, Event.AddressSpent.name(), struct(Event.AddressSpent, event_trigger)}
  end

  defp get_address_received_events(
         %{
           tx: %Transaction.Recovered{
             signed_tx: %Transaction.Signed{raw_tx: %Transaction{newowner1: newowner1, newowner2: newowner2}}
           }
         } = event_trigger
       ) do
    [newowner1, newowner2]
    |> Enum.filter(&Transaction.account_address?/1)
    |> Enum.map(&create_address_received_event(event_trigger, &1))
    |> Enum.uniq()
  end

  defp create_address_received_event(event_trigger, address) do
    subtopic = create_transfer_subtopic(address)

    {subtopic, Event.AddressReceived.name(), struct(Event.AddressReceived, event_trigger)}
  end

  defp create_transfer_subtopic(address) do
    {:ok, encoded_address} = Crypto.encode_address(address)
    create_subtopic(@transfer_topic, encoded_address)
  end

  defp create_subtopic(main_topic, subtopic), do: main_topic <> ":" <> subtopic
end

# Copyright 2018 OmiseGO Pte Ltd
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

defmodule OMG.Watcher.Eventer.Core do
  @moduledoc """
  Functional core of eventer
  """

  alias OMG.API.Crypto
  alias OMG.API.State.Transaction
  alias OMG.Watcher.Eventer.Event

  @transfer_topic "transfer"
  @byzantine_topic "byzantine"

  @spec pair_events_with_topics(any() | Event.t()) :: list({String.t(), String.t(), Event.t()})
  def pair_events_with_topics(event_triggers) do
    Enum.flat_map(event_triggers, &get_event_with_topic(&1))
  end

  defp get_event_with_topic(%Event.InvalidBlock{} = event) do
    [{@byzantine_topic, Event.InvalidBlock.name(), event}]
  end

  defp get_event_with_topic(%Event.BlockWithholding{} = event) do
    [{@byzantine_topic, Event.BlockWithholding.name(), event}]
  end

  defp get_event_with_topic(%Event.InvalidExit{} = event) do
    [{@byzantine_topic, Event.InvalidExit.name(), event}]
  end

  # NOTE: the deposit events are silenced because of the desired behavior not being defined yet, pending OMG-177
  defp get_event_with_topic(%{deposit: _deposit}), do: []

  defp get_event_with_topic(%{tx: _tx} = event_trigger) do
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

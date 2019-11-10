# Copyright 2019 OmiseGO Pte Ltd
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

defmodule OMG.WatcherSecurity.Eventer.Core do
  @moduledoc """
  Functional core of eventer
  """

  alias OMG.State.Transaction
  alias OMG.Utils.HttpRPC.Encoding
  alias OMG.Utxo
  alias OMG.WatcherSecurity.Event

  require OMG.Utxo

  defstruct []

  @type t() :: %__MODULE__{}

  @transfer_topic "transfer"
  @exit_topic "exit"
  @zero_address OMG.Eth.zero_address()

  def init, do: %__MODULE__{}

  @spec pair_events_with_topics(any() | Event.t()) :: list({String.t(), String.t(), Event.t()})
  def pair_events_with_topics(event_triggers) do
    Enum.flat_map(event_triggers, &get_event_with_topic(&1))
  end

  # NOTE: the deposit events are silenced because of the desired behavior not being defined yet, pending OMG-177
  defp get_event_with_topic(%{deposit: _deposit}), do: []

  defp get_event_with_topic(%{exit: _exit}), do: []

  defp get_event_with_topic(%{
         exit_finalized: %{
           owner: owner,
           currency: currency,
           amount: amount,
           utxo_pos: Utxo.position(blknum, txindex, oindex)
         }
       }) do
    [
      {create_exit_subtopic(owner), "exit_finalized",
       struct(Event.ExitFinalized, %{
         owner: owner,
         currency: currency,
         amount: amount,
         child_blknum: blknum,
         child_txindex: txindex,
         child_oindex: oindex
       })}
    ]
  end

  defp get_event_with_topic(%{tx: _tx} = event_trigger) do
    get_address_received_events(event_trigger) ++ get_address_spent_events(event_trigger)
  end

  defp get_address_spent_events(%{tx: %Transaction.Recovered{witnesses: witnesses}} = event_trigger) do
    witnesses
    |> Map.values()
    # makes sure only spender witnesses are used here. This should fail&crash when other kinds of witnesses go through
    |> Enum.filter(&account_address?/1)
    |> Enum.map(&create_address_spent_event(event_trigger, &1))
    |> Enum.uniq()
  end

  defp create_address_spent_event(event_trigger, address) do
    subtopic = create_transfer_subtopic(address)
    {subtopic, "address_spent", struct(Event.AddressSpent, event_trigger)}
  end

  defp get_address_received_events(%{tx: tx} = event_trigger) do
    tx
    |> Transaction.get_outputs()
    |> Enum.map(fn %{owner: owner} -> owner end)
    |> Enum.filter(&account_address?/1)
    |> Enum.map(&create_address_received_event(event_trigger, &1))
    |> Enum.uniq()
  end

  defp account_address?(@zero_address), do: false
  defp account_address?(address) when is_binary(address) and byte_size(address) == 20, do: true

  defp create_address_received_event(event_trigger, address) do
    subtopic = create_transfer_subtopic(address)

    {subtopic, "address_received", struct(Event.AddressReceived, event_trigger)}
  end

  defp create_transfer_subtopic(address) do
    create_subtopic(@transfer_topic, Encoding.to_hex(address))
  end

  defp create_exit_subtopic(address) do
    create_subtopic(@exit_topic, Encoding.to_hex(address))
  end

  defp create_subtopic(main_topic, subtopic), do: main_topic <> ":" <> subtopic
end

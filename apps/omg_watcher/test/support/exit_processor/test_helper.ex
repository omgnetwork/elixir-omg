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

defmodule OMG.Watcher.ExitProcessor.TestHelper do
  @moduledoc """
  Common utilities to manipulate the `ExitProcessor`
  """

  alias OMG.State.Transaction
  alias OMG.Utxo
  alias OMG.Watcher.ExitProcessor.Core

  require Utxo

  @eth OMG.Eth.RootChain.eth_pseudo_address()
  @zero_address OMG.Eth.zero_address()
  @exit_id 1

  def start_se_from(%Core{} = processor, tx, exiting_pos, opts \\ []) do
    {event, status} = se_event_status(tx, exiting_pos, opts)
    {processor, _} = Core.new_exits(processor, [event], [status])
    processor
  end

  def se_event_status(tx, exiting_pos, opts \\ []) do
    Utxo.position(_, _, oindex) = exiting_pos
    txbytes = Transaction.raw_txbytes(tx)
    enc_pos = Utxo.Position.encode(exiting_pos)
    owner = tx |> Transaction.get_outputs() |> Enum.at(oindex) |> Map.get(:owner)
    eth_height = Keyword.get(opts, :eth_height, 2)

    call_data = %{utxo_pos: enc_pos, output_tx: txbytes}
    event = %{owner: owner, eth_height: eth_height, exit_id: @exit_id, call_data: call_data}

    status =
      Keyword.get(opts, :status) ||
        if(Keyword.get(opts, :inactive), do: {@zero_address, @eth, 10, enc_pos}, else: {owner, @eth, 10, enc_pos})

    {event, status}
  end

  def start_ife_from(%Core{} = processor, tx, opts \\ []) do
    status = Keyword.get(opts, :status, {1, @exit_id})
    {processor, _} = Core.new_in_flight_exits(processor, [ife_event(tx, opts)], [status])
    processor
  end

  def piggyback_ife_from(%Core{} = processor, tx_hash, output_index) do
    {processor, _} = Core.new_piggybacks(processor, [%{tx_hash: tx_hash, output_index: output_index}])
    processor
  end

  def ife_event(tx, opts \\ []) do
    sigs = Keyword.get(opts, :sigs) || get_sigs(tx)
    eth_height = Keyword.get(opts, :eth_height, 2)

    %{
      call_data: %{in_flight_tx: Transaction.raw_txbytes(tx), in_flight_tx_sigs: Enum.join(sigs)},
      eth_height: eth_height
    }
  end

  def ife_response(tx, position),
    do: %{tx_hash: Transaction.raw_txhash(tx), challenge_position: Utxo.Position.encode(position)}

  defp get_sigs(%{signed_tx: %{sigs: sigs}}), do: sigs
end

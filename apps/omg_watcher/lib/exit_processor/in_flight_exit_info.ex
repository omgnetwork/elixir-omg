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

defmodule OMG.Watcher.ExitProcessor.InFlightExitInfo do
  @moduledoc """
  Represents the bulk of information about a tracked in-flight exit.

  Internal stuff of `OMG.Watcher.ExitProcessor`
  """

  alias OMG.API.State.Transaction
  alias OMG.API.Utxo

  defstruct [
    :tx,
    :tx_pos,
    :timestamp,
    # piggybacking
    exit_map: 0..7 |> Enum.map(&{&1, %{is_piggybacked: false, is_finalized: false}}) |> Map.new(),
    oldest_competitor: 0,
    is_canonical: true,
    is_active: true
  ]

  @type t :: %__MODULE__{
          tx: Transaction.Signed.t(),
          tx_pos: Utxo.Position.t(),
          timestamp: non_neg_integer(),
          exit_map: %{non_neg_integer() => %{is_piggybacked: boolean(), is_finalized: boolean()}},
          oldest_competitor: non_neg_integer(),
          is_canonical: boolean(),
          is_active: boolean()
        }

  def build_in_flight_transaction_info(tx_bytes, tx_signatures, timestamp, is_active) do
    with {:ok, raw_tx} <- Transaction.decode(tx_bytes) do
      signed_tx_map = %{
        raw_tx: raw_tx,
        sigs: tx_signatures
      }

      {
        Transaction.hash(raw_tx),
        %__MODULE__{
          tx: struct(Transaction.Signed, signed_tx_map),
          timestamp: timestamp,
          is_active: is_active
        }
      }
    end
  end

  def make_db_update({_ife_hash, %__MODULE__{} = _ife_info} = update) do
    {:put, :in_flight_exit_info, update}
  end

  def piggyback(%__MODULE__{} = ife, index) do
    with {:ok, exit} <- Map.fetch(ife.exit_map, index),
         true <- can_be_piggybacked?(exit) do
      updated_ife =
        exit
        |> Map.put(:is_piggybacked, true)
        |> (&Map.put(ife.exit_map, index, &1)).()
        |> (&Map.put(ife, :exit_map, &1)).()

      {:ok, updated_ife}
    else
      :error -> {:error, :non_existent_exit}
      false -> {:error, :cannot_piggyback}
    end
  end

  defp can_be_piggybacked?(%{is_piggybacked: false, is_finalized: false}), do: true
  defp can_be_piggybacked?(_exit), do: false

  def get_exiting_utxo_positions(%__MODULE__{is_canonical: false} = ife) do
    ife.inputs
    |> Enum.with_index()
    |> Enum.filter(&is_active?(ife, :input, elem(&1, 1)))
    |> Enum.map(&(&1 |> elem(0) |> elem(0)))
  end

  def get_exiting_utxo_positions(ife = %__MODULE__{is_canonical: true, tx_pos: tx_pos}) when tx_pos != nil do
    active_outputs_offsets =
      ife.outputs
      |> Enum.with_index()
      |> Enum.filter(&is_active?(ife, :input, elem(&1, 1)))
      |> Enum.map(&(&1 |> elem(1)))

    {:utxo_position, blknum, txindex, _} = tx_pos
    for pos <- active_outputs_offsets, do: {:utxo_position, blknum, txindex, pos}
  end

  def get_exiting_utxo_positions(_) do
    []
  end

  def is_piggybacked?(%__MODULE__{exit_map: _map}, _type, _index) do
    true
  end

  def is_finalized?(%__MODULE__{exit_map: _map}, _type, _index) do
    #    read_bit(bitmap, 8 + index + offset(type)) == 1
    true
  end

  def is_active?(ife, type, index) do
    is_piggybacked?(ife, type, index) and not is_finalized?(ife, type, index)
  end

  #  defp offset(:input), do: 0
  #  defp offset(:output), do: 4
end

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

defmodule OMG.State.UtxoSet do
  @moduledoc """
  Handles all the operations done on the UTXOs held in the ledger

  It will provide the requested UTXOs by a collection of inputs, trade in transaction effects (new utxos, utxos to delete).

  It also translates the modifications to it into DB updates, and is able to interpret the UTXO query result from DB
  """

  alias OMG.Utxo

  require Utxo

  def init(utxos_query_result) do
    Enum.into(utxos_query_result, %{}, fn {db_position, db_utxo} ->
      {Utxo.Position.from_db_key(db_position), Utxo.from_db_value(db_utxo)}
    end)
  end

  @doc """
  Provides the outputs that are pointed by `inputs` provided
  """
  def get_by_inputs(utxos, inputs) do
    with {:ok, utxos_for_inputs} <- get_utxos_by_inputs(utxos, inputs),
         do: {:ok, utxos_for_inputs |> Enum.reverse() |> Enum.map(fn %Utxo{output: output} -> output end)}
  end

  @doc """
  Updates itself given a list of spent input pointers and a map of UTXOs created upon a transaction
  """
  def apply_effects(utxos, spent_input_pointers, new_utxos_map) do
    utxos |> Map.drop(spent_input_pointers) |> Map.merge(new_utxos_map)
  end

  @doc """
  Returns the DB updates required given a list of spent input pointers and a map of UTXOs created upon a transaction
  """
  @spec db_updates(list(Utxo.Position.t()), %{Utxo.Position.t() => Utxo.t()}) ::
          list({:put, :utxo, {Utxo.Position.db_t(), Utxo.t()}} | {:delete, :utxo, Utxo.Position.db_t()})
  def db_updates(spent_input_pointers, new_utxos_map) do
    db_updates_new_utxos = new_utxos_map |> Enum.map(&utxo_to_db_put/1)
    db_updates_spent_utxos = spent_input_pointers |> Enum.map(&utxo_to_db_delete/1)
    Enum.concat(db_updates_new_utxos, db_updates_spent_utxos)
  end

  def exists?(utxos, input_pointer),
    do: Map.has_key?(utxos, input_pointer)

  @doc """
  Searches the UTXO set for a particular UTXO created with a `tx_hash` on `oindex` position.

  Current implementation is **expensive**
  """
  def scan_for_matching_utxo(utxos, tx_hash, oindex) do
    Enum.find(utxos, &match?({Utxo.position(_, _, ^oindex), %Utxo{creating_txhash: ^tx_hash}}, &1))
  end

  defp get_utxos_by_inputs(utxos, inputs) do
    inputs
    |> Enum.reduce_while({:ok, []}, fn input, acc -> get_utxo(utxos, input, acc) end)
  end

  defp get_utxo(utxos, position, {:ok, acc}) do
    case Map.get(utxos, position) do
      nil -> {:halt, {:error, :utxo_not_found}}
      found -> {:cont, {:ok, [found | acc]}}
    end
  end

  defp utxo_to_db_put({utxo_pos, utxo}),
    do: {:put, :utxo, {Utxo.Position.to_db_key(utxo_pos), Utxo.to_db_value(utxo)}}

  defp utxo_to_db_delete(utxo_pos),
    do: {:delete, :utxo, Utxo.Position.to_db_key(utxo_pos)}
end

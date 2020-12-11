# Copyright 2019-2020 OMG Network Pte Ltd
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
  Handles all the operations done on the UTXOs held in the ledger.
  Provides the requested UTXOs by a collection of input pointers.
  Trades in transaction effects (new utxos, utxos to delete).

  Translates the modifications to itself into DB updates, and is able to interpret the UTXO query result from DB.

  Intended to handle any kind UTXO _subsets_ of the entire UTXO set, relying on that the subset of UTXOs is selected
  correctly.
  """

  alias OMG.Crypto

  alias OMG.Output
  alias OMG.State.Transaction
  alias OMG.Utxo

  require Utxo

  @type t() :: %{OMG.Utxo.Position.t() => Utxo.t()}
  @type query_result_t() :: list({OMG.DB.utxo_pos_db_t(), OMG.Utxo.t()})

  @spec init(query_result_t()) :: t()
  def init(utxos_query_result) do
    utxos_query_result
    |> Enum.reject(&(&1 == :not_found))
    |> Enum.into(%{}, fn {db_input_pointer, db_utxo} ->
      {OMG.Utxo.Position.from_db_key(db_input_pointer), Utxo.from_db_value(db_utxo)}
    end)
  end

  @doc """
  Provides the outputs that are pointed by `inputs` provided
  """
  @spec get_by_inputs(t(), list(OMG.Utxo.Position.t())) ::
          {:ok, list(Output.t())} | {:error, :utxo_not_found}
  def get_by_inputs(utxos, inputs) do
    with {:ok, utxos_for_inputs} <- get_utxos_by_inputs(utxos, inputs),
         do: {:ok, utxos_for_inputs |> Enum.reverse() |> Enum.map(fn %Utxo{output: output} -> output end)}
  end

  @doc """
  Updates itself given a list of spent input pointers and a map of UTXOs created upon a transaction
  """
  @spec apply_effects(t(), list(OMG.Utxo.Position.t()), t()) :: t()
  def apply_effects(utxos, spent_input_pointers, new_utxos_map) do
    utxos |> Map.merge(new_utxos_map) |> Map.drop(spent_input_pointers)
  end

  @doc """
  Returns the DB updates required given a list of spent input pointers and a map of UTXOs created upon a transaction
  """
  @spec db_updates(list(OMG.Utxo.Position.t()), t()) ::
          list({:put, :utxo, {Utxo.Position.db_t(), Utxo.t()}} | {:delete, :utxo, Utxo.Position.db_t()})
  def db_updates(spent_input_pointers, new_utxos_map) do
    db_updates_new_utxos = new_utxos_map |> Enum.map(&utxo_to_db_put/1)
    db_updates_spent_utxos = spent_input_pointers |> Enum.map(&utxo_to_db_delete/1)
    Enum.concat(db_updates_new_utxos, db_updates_spent_utxos)
  end

  @spec exists?(t(), OMG.Utxo.Position.t()) :: boolean()
  def exists?(utxos, input_pointer),
    do: Map.has_key?(utxos, input_pointer)

  @doc """
  Searches the UTXO set for a particular UTXO created with a `txhash` on `oindex` position.

  Current implementation is **expensive**
  """
  @spec find_matching_utxo(t(), Transaction.tx_hash(), non_neg_integer()) :: {OMG.Utxo.Position.t(), Utxo.t()}
  def find_matching_utxo(utxos, requested_txhash, oindex) do
    utxos
    |> Stream.filter(&utxo_kv_created_by?(&1, requested_txhash))
    |> Enum.find(&utxo_kv_has_oindex_equal?(&1, oindex))
  end

  @doc """
  Streams the UTXO key-value pairs found to be owner by a particular address
  """
  @spec filter_owned_by(t(), Crypto.address_t()) :: Enumerable.t()
  def filter_owned_by(utxos, address) do
    Stream.filter(utxos, fn utxo_kv -> utxo_kv_get_owner(utxo_kv) == address end)
  end

  @doc """
  Turns any enumerable of UTXOs (for example an instance of `OMG.State.UtxoSet.t` here) and produces a new enumerable
  where the UTXO k-v pairs got zipped with UTXO positions coming from the data confined in the UTXO set
  """
  @spec zip_with_positions(t() | Enumerable.t()) :: Enumerable.t()
  def zip_with_positions(utxos) do
    Stream.map(utxos, fn utxo_kv -> {utxo_kv, utxo_kv_get_position(utxo_kv)} end)
  end

  defp get_utxos_by_inputs(utxos, inputs) do
    Enum.reduce_while(inputs, {:ok, []}, fn input, acc -> get_utxo(utxos, input, acc) end)
  end

  defp get_utxo(utxos, position, {:ok, acc}) do
    case Map.get(utxos, position) do
      nil -> {:halt, {:error, :utxo_not_found}}
      found -> {:cont, {:ok, [found | acc]}}
    end
  end

  defp utxo_to_db_put({input_pointer, utxo}),
    do: {:put, :utxo, {Utxo.Position.to_input_db_key(input_pointer), Utxo.to_db_value(utxo)}}

  defp utxo_to_db_delete(input_pointer),
    do: {:delete, :utxo, Utxo.Position.to_input_db_key(input_pointer)}

  # based on some key-value pair representing {input_pointer, utxo}, get its position from somewhere
  defp utxo_kv_get_position(utxo_kv)
  defp utxo_kv_get_position({Utxo.position(_, _, _) = utxo_pos, _utxo}), do: utxo_pos
  defp utxo_kv_get_position({_non_utxo_pos_input_pointer, %{utxo_pos: Utxo.position(_, _, _) = utxo_pos}}), do: utxo_pos

  # based on some key-value pair representing {input_pointer, utxo}, get its owner
  defp utxo_kv_get_owner(utxo_kv)
  defp utxo_kv_get_owner({_input_pointer, %Utxo{output: %{owner: owner}}}), do: owner
  defp utxo_kv_get_owner({%{owner: owner}, _output_without_owner_specified}), do: owner

  defp utxo_kv_created_by?({_input_pointer, %Utxo{creating_txhash: requested_txhash}}, requested_txhash), do: true
  defp utxo_kv_created_by?({_input_pointer, %Utxo{}}, _), do: false

  defp utxo_kv_has_oindex_equal?(utxo_kv, oindex) do
    Utxo.position(_, _, utxo_kv_oindex) = utxo_kv_get_position(utxo_kv)
    utxo_kv_oindex == oindex
  end
end

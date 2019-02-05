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

defmodule OMG.DB.LevelDBCore do
  @moduledoc """
  Responsible for converting type-aware, logic-specific queries and updates into leveldb specific queries and updates
  """

  # adapter - testable, if we really really want to

  @keys_prefixes %{
    block: "b",
    block_hash: "bn",
    utxo: "u",
    exit_info: "e",
    in_flight_exit_info: "ife",
    competitor_info: "ci",
    spend: "s"
  }

  @key_types Map.keys(@keys_prefixes)

  def parse_multi_updates(db_updates) do
    db_updates
    |> Enum.flat_map(&parse_multi_update/1)
  end

  defp parse_multi_update({:put, :block, %{number: number, hash: hash} = item}) do
    [
      {:put, key_for_item(:block, item), encode_value(:block, item)},
      {:put, key(:block_hash, number), encode_value(:block_hash, hash)}
    ]
  end

  defp parse_multi_update({:put, type, item}), do: [{:put, key_for_item(type, item), encode_value(type, item)}]
  defp parse_multi_update({:delete, type, item}), do: [{:delete, key(type, item)}]

  defp decode_response(_type, db_response) do
    case db_response do
      :not_found -> :not_found
      {:ok, encoded} -> :erlang.binary_to_term(encoded)
      other -> {:error, other}
    end
  end

  @doc """
  Interprets the response from leveldb and returns a success-decorated result
  """
  def decode_value(db_response, type) do
    case decode_response(type, db_response) do
      {:error, error} -> {:error, error}
      other -> {:ok, other}
    end
  end

  @doc """
  Interprets an enumerable of responses from leveldb and decorates the enumerable with a `{:ok, _enumerable}`
  if no errors occurred
  """
  def decode_values(encoded_enumerable, type) do
    raw_decoded =
      encoded_enumerable
      |> Enum.map(fn encoded -> decode_response(type, encoded) end)

    if Enum.any?(raw_decoded, &match?({:error, _}, &1)),
      do: {:error, raw_decoded},
      else: {:ok, raw_decoded}
  end

  defp encode_value(:spend, {_position, blknum}), do: :erlang.term_to_binary(blknum)
  defp encode_value(_type, value), do: :erlang.term_to_binary(value)

  def filter_keys(key_stream, type) when type in @key_types,
    do: do_filter_keys(key_stream, Map.get(@keys_prefixes, type))

  defp do_filter_keys(keys_stream, prefix),
    do: Stream.filter(keys_stream, fn {key, _} -> String.starts_with?(key, prefix) end)

  @single_value_parameter_names [
    :child_top_block_number,
    :last_deposit_child_blknum,
    :last_block_getter_eth_height,
    :last_depositor_eth_height,
    :last_exiter_eth_height,
    :last_piggyback_exit_eth_height,
    :last_in_flight_exit_eth_height,
    :last_exit_processor_eth_height,
    :last_exit_finalizer_eth_height,
    :last_exit_challenger_eth_height,
    :last_in_flight_exit_processor_eth_height,
    :last_piggyback_processor_eth_height,
    :last_competitor_processor_eth_height,
    :last_challenges_responds_processor_eth_height,
    :last_piggyback_challenges_processor_eth_height,
    :last_ife_exit_finalizer_eth_height
  ]

  @doc """
  Produces a type-specific LevelDB key for a combination of type and type-agnostic/LevelDB-ignorant key
  """
  def key(:block, hash) when is_binary(hash), do: @keys_prefixes.block <> hash
  def key(parameter, _) when parameter in @single_value_parameter_names, do: Atom.to_string(parameter)

  def key(type, specific_key) when type in @key_types,
    do: Map.get(@keys_prefixes, type) <> :erlang.term_to_binary(specific_key)

  # `key_for_item` gets the type-specific key to persist a whole item at, as used by `:put` updates
  defp key_for_item(:block, %{hash: hash} = _block), do: key(:block, hash)
  defp key_for_item(:utxo, {position, _utxo}), do: key(:utxo, position)
  defp key_for_item(:spend, {position, _blknum}), do: key(:spend, position)
  defp key_for_item(:exit_info, {position, _exit_info}), do: key(:exit_info, position)
  defp key_for_item(:in_flight_exit_info, {position, _info}), do: key(:in_flight_exit_info, position)
  defp key_for_item(:competitor_info, {position, _info}), do: key(:competitor_info, position)
  defp key_for_item(parameter, value) when parameter in @single_value_parameter_names, do: key(parameter, value)
end

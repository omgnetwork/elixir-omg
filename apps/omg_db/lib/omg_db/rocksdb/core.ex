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

defmodule OMG.DB.RocksDB.Core do
  @moduledoc """
  Responsible for converting type-aware, logic-specific queries and updates into rocksdb specific queries and updates
  """

  # adapter - testable, if we really really want to
  use Spandex.Decorators

  @single_value_parameter_names OMG.DB.single_value_parameter_names()

  # if we keep the prefix byte size consistent across all keys, we're able to use
  # prefix extractor to reduce the number of IO scans
  # more https://github.com/facebook/rocksdb/wiki/Prefix-Seek-API-Changes
  @keys_prefixes %{
    # watcher (Exit Processor) and child chain (Fresh Blocks)
    block: "block",
    # watcher (Exit Processor) and child chain (Block Queue)
    block_hash: "hashb",
    # watcher and child chain
    utxo: "utxoi",
    # watcher and child chain
    exit_info: "exiti",
    # watcher only
    in_flight_exit_info: "infle",
    # watcher only
    competitor_info: "compi",
    # watcher only
    spend: "spend",
    # watcher and child chain
    omg_eth_contracts: "omg_eth_contracts"
  }

  @key_types Map.keys(@keys_prefixes)

  def parse_multi_updates(db_updates), do: Enum.flat_map(db_updates, &parse_multi_update/1)

  @doc """
  Interprets the response from rocksdb and returns a success-decorated result
  """
  @spec decode_value({:ok, binary()} | :not_found) :: {:ok, term()} | :not_found
  def decode_value(db_response) do
    case decode_response(db_response) do
      :not_found -> :not_found
      other -> {:ok, other}
    end
  end

  @doc """
  Interprets an enumerable of responses from rocksdb and decorates the enumerable with a `{:ok, _enumerable}`
  if no errors occurred
  """
  @spec decode_values(Enumerable.t()) :: {:ok, list}
  def decode_values(encoded_enumerable) do
    raw_decoded = Enum.map(encoded_enumerable, fn encoded -> decode_response(encoded) end)
    {:ok, raw_decoded}
  end

  def filter_keys(key_stream, type) when type in @key_types,
    do: do_filter_keys(key_stream, Map.get(@keys_prefixes, type))

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

  defp parse_multi_update({:put, :block, %{number: number, hash: hash} = item}) do
    [
      {:put, key_for_item(:block, item), encode_value(:block, item)},
      {:put, key(:block_hash, number), encode_value(:block_hash, hash)}
    ]
  end

  defp parse_multi_update({:put, type, item}), do: [{:put, key_for_item(type, item), encode_value(type, item)}]
  defp parse_multi_update({:delete, type, item}), do: [{:delete, key(type, item)}]

  defp encode_value(:spend, {_position, blknum}), do: :erlang.term_to_binary(blknum)
  defp encode_value(_type, value), do: :erlang.term_to_binary(value)

  # sobelow_skip ["Misc.BinToTerm"]
  defp decode_response(db_response) do
    case db_response do
      :not_found ->
        :not_found

      {:ok, encoded} ->
        :erlang.binary_to_term(encoded, [:safe])

      encoded ->
        # iterator search returns raw values
        :erlang.binary_to_term(encoded, [:safe])
    end
  end

  defp do_filter_keys(reference, prefix) do
    # https://github.com/facebook/rocksdb/wiki/Prefix-Seek-API-Changes#use-readoptionsprefix_seek
    {:ok, iterator} = :rocksdb.iterator(reference, prefix_same_as_start: true)
    move_iterator = :rocksdb.iterator_move(iterator, {:seek, prefix})
    Enum.reverse(search(reference, iterator, move_iterator, []))
  end

  defp search(_reference, _iterator, {:error, :invalid_iterator}, acc), do: acc
  defp search(reference, iterator, {:ok, _key, value}, acc), do: do_search(reference, iterator, [value | acc])

  defp do_search(reference, iterator, acc) do
    case :rocksdb.iterator_move(iterator, :next) do
      {:error, :invalid_iterator} ->
        # we've reached the end
        :rocksdb.iterator_close(iterator)
        acc

      {:ok, _key, value} ->
        do_search(reference, iterator, [value | acc])
    end
  end
end

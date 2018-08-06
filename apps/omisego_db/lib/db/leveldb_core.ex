defmodule OmiseGO.DB.LevelDBCore do
  @moduledoc """
  Responsible for converting type-aware, logic-specific queries (updates) into backend specific queries (updates)
  """

  # adapter - testable, if we really really want to

  def parse_multi_updates(db_updates) do
    db_updates
    |> Enum.flat_map(&parse_multi_update/1)
  end

  defp parse_multi_update({:put, :block, %{number: number, hash: hash} = item}) do
    [
      {:put, key(:block, item), encode_value(:block, item)},
      {:put, key(:block_hash, number), encode_value(:block_hash, hash)}
    ]
  end

  defp parse_multi_update({:put, type, item}), do: [{:put, key(type, item), encode_value(type, item)}]
  defp parse_multi_update({:delete, type, item}), do: [{:delete, key(type, item)}]

  defp decode_response(_type, db_response) do
    case db_response do
      :not_found -> :not_found
      {:ok, encoded} -> :erlang.binary_to_term(encoded)
      other -> {:error, other}
    end
  end

  @doc """
  Interprepts the response from leveldb and returns a success-decorated result
  """
  def decode_value(db_response, type) do
    case decode_response(type, db_response) do
      {:error, error} -> {:error, error}
      other -> {:ok, other}
    end
  end

  @doc """
  Interprets an enumberable of responses from leveldb and decorates the enumerable with a {:ok, _enumberable}
  if no errors occurred
  """
  def decode_values(encoded_enumerable, type) do
    raw_decoded =
      encoded_enumerable
      |> Enum.map(fn encoded -> decode_response(type, encoded) end)

    is_error? = fn result ->
      case result do
        {:error, _} -> true
        _ -> false
      end
    end

    if Enum.any?(raw_decoded, is_error?) do
      {:error, raw_decoded}
    else
      {:ok, raw_decoded}
    end
  end

  defp encode_value(_type, value), do: :erlang.term_to_binary(value)

  def filter_utxos(keys_stream) do
    keys_stream
    |> Stream.filter(fn
      "u" <> _rest -> true
      _ -> false
    end)
  end

  def key(:block, %{hash: hash} = _block), do: key(:block, hash)
  def key(:block, hash), do: "b" <> hash

  def key(:block_hash, number), do: "bn" <> :erlang.term_to_binary(number)

  def key(:utxo, {position, _utxo}) do
    key(:utxo, position)
  end

  def key(:utxo, position) do
    "u" <> :erlang.term_to_binary(position)
  end

  def key(:last_deposit_block_height, _), do: "last_deposit_block_height"
  def key(:child_top_block_number, _), do: "child_top_block_number"
  def key(:last_fast_exit_block_height, _), do: "last_fast_exit_block_height"
  def key(:last_slow_exit_block_height, _), do: "last_slow_exit_block_height"
end

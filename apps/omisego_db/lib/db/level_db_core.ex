defmodule OmiseGO.DB.LevelDBCore do
  @moduledoc """
  Responsible for converting type-aware, logic-specific queries (updates) into backend specific queries (updates)
  """

  # adapter - testable, if we really really want to

  def parse_multi_updates(db_updates) do
    db_updates
    |> Enum.map(&parse_multi_update/1)
  end

  # TODO, switch to selecting the clause base on the type of tx/block/utxo (struct?)
  defp parse_multi_update({:put, :tx, tx}), do: {:put, tx_key(tx), encode_value(:tx, tx)}
  defp parse_multi_update({:put, :block, block}), do: {:put, block_key(block), encode_value(:block, block)}
  defp parse_multi_update({:put, :utxo, utxo}), do: {:put, utxo_key(utxo), encode_value(:utxo, utxo)}

  defp parse_multi_update({:delete, :tx, tx}), do: {:delete, tx_key(tx)}
  defp parse_multi_update({:delete, :block, block}), do: {:delete, block_key(block)}
  defp parse_multi_update({:delete, :utxo, utxo}), do: {:delete, utxo_key(utxo)}

  def decode_value(:block, encoded), do: Poison.decode(encoded)
  def decode_value(:tx, encoded), do: Poison.decode(encoded)
  def decode_value(:utxo, encoded) do
    with {:ok, %{"b" => b, "t" => t, "o" => o, "value" => utxo_value}} <- Poison.decode(encoded),
         do: %{{b, t, o} => utxo_value}
  end

  defp encode_value(:tx, value), do: Poison.encode!(value)
  defp encode_value(:block, value), do: Poison.encode!(value)
  defp encode_value(:utxo, utxo) do
    [{b, t, o}] = Map.keys(utxo)
    [utxo_value] = Map.values(utxo)

    %{b: b, t: t, o: o, value: utxo_value}
    |> Poison.encode!
  end

  def filter_utxos(keys_stream) do
    keys_stream
    # |> Stream.map(&IO.inspect/1)
    |> Stream.filter(fn
      "u" <> _rest -> true
      _ -> false
    end)
    # |> Stream.map(&IO.inspect/1)
  end

  def tx_key(%{hash: hash} = _tx) do
    tx_key(hash)
  end
  def tx_key(hash), do: "t" <> hash

  def block_key(%{hash: hash} = _block), do: block_key(hash)
  def block_key(hash), do: "b" <> hash

  def utxo_list_key do
    "utxos"
  end

  def utxo_key(utxo) when is_map(utxo) do
    [utxo_id] = Map.keys(utxo)
    utxo_key(utxo_id)
  end
  def utxo_key({blknum, txindex, oindex} = _utxo_id) do
    # FIXME: very bad, fix
    "u" <> Integer.to_string(blknum) <> Integer.to_string(txindex) <> Integer.to_string(oindex)
  end
end

defmodule OmiseGO.DB.LevelDBCore do
  @moduledoc """
  Responsible for converting type-aware, logic-specific queries (updates) into backend specific queries (updates)
  """

  # adapter - testable, if we really really want to

  def parse_multi_updates(db_updates) do
    db_updates
    |> Enum.map(&parse_multi_update/1)
  end

  defp parse_multi_update({:put, :tx, tx}), do: {:put, tx_key(tx), encode_value(tx)}
  defp parse_multi_update({:put, :block, block}), do: {:put, block_key(block), encode_value(block)}
  defp parse_multi_update({:put, :utxo, utxo}), do: {:put, utxo_key(utxo), encode_value(utxo)}

  defp parse_multi_update({:delete, :tx, tx}), do: {:delete, tx_key(tx)}
  defp parse_multi_update({:delete, :block, block}), do: {:delete, block_key(block)}
  defp parse_multi_update({:delete, :utxo, utxo}), do: {:delete, utxo_key(utxo)}

  defp encode_value(value), do: Poison.encode!(value)

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
    <<"u", Integer.to_string(blknum), Integer.to_string(txindex), Integer.to_string(oindex)>>
  end
end

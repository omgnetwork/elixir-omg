defmodule OmiseGO.DB.LevelDBCore do
  @moduledoc """
  Responsible for converting type-aware, logic-specific queries (updates) into backend specific queries (updates)
  """

  # adapter - testable, if we really really want to

  def parse_multi_updates(db_updates) do
    db_updates
    |> Enum.map(&parse_multi_update/1)
  end

  defp parse_multi_update({:put, :tx, tx}), do: {:put, tx_key(tx), leveldb_encode_value(tx)}
  defp parse_multi_update({:put, :block, block}), do: {:put, block_key(block), leveldb_encode_value(block)}
  defp parse_multi_update({:put, :utxo, utxo}), do: {:put, utxo_key(utxo), leveldb_encode_value(utxo)}

  defp parse_multi_update({:delete, :tx, tx}), do: {:delete, tx_key(tx)}
  defp parse_multi_update({:delete, :block, block}), do: {:delete, block_key(block)}
  defp parse_multi_update({:delete, :utxo, utxo}), do: {:delete, utxo_key(utxo)}

  defp leveldb_encode_value(value), do: Poison.encode!(value)

  def tx_key(%{hash: hash} = _tx) do
    "t" <> hash
  end

  def block_key(%{hash: hash} = _block) do
    "b" <> hash
  end

  def utxo_list_key do
    "utxos"
  end

  def utxo_key(utxo) do
    [{blknum, txindex, oindex}] = Map.keys(utxo)
    # FIXME: very bad, fix
    <<"u", Integer.to_string(blknum), Integer.to_string(txindex), Integer.to_string(oindex)>>
  end
end

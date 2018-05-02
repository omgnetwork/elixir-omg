defmodule OmiseGOWatcherWeb.Controller.Utxo do
  @moduledoc"""
  Operations related to utxo.
  Modify the state in the database.
  """
  alias OmiseGOWatcher.{Repo, UtxoDB, TransactionDB}
  alias OmiseGO.API.Crypto
  alias OmiseGOWatcher.TransactionDB

  use OmiseGOWatcherWeb, :controller
  import Ecto.Query, only: [from: 2]

  @transaction_merkle_tree_height 16

  def available(conn, %{"address" => address}) do
    utxos = Repo.all(from(tr in UtxoDB, where: tr.address == ^address, select: tr))
    fields_names = List.delete(UtxoDB.field_names(), :address)

    json(conn, %{
      address: address,
      utxos: Enum.map(utxos, &Map.take(&1, fields_names))
    })
  end

  def compose_utxo_exit(conn, %{"block_height" => block_height, "txindex" => txindex, "oindex" => oindex}) do
    txs = TransactionDB.find_by_txblknum(block_height)

    hashed_txs = txs |> Enum.map(&(&1.txid))

    {:ok, mt} = MerkleTree.new(hashed_txs, &Crypto.hash/1, @transaction_merkle_tree_height)

    tx_index = Enum.find_index(txs, fn(tx) -> tx.txindex == String.to_integer(txindex) end)

    proof = MerkleTree.Proof.prove(mt, tx_index)

    bin_to_list = fn x -> :binary.bin_to_list(x) end

    tx_bytes =
      txs
      |> Enum.at(tx_index)
      |> TransactionDB.encode
      |> bin_to_list.()

    json(conn, %{
      utxo_pos: calculate_utxo_pos(block_height, txindex, oindex),
      tx_bytes: tx_bytes,
      proof: Enum.map(proof.hashes, bin_to_list)
    })

  end

  defp calculate_utxo_pos(block_height, txindex, oindex) do
    {block_height, _} = Integer.parse(block_height)
    {txindex, _} = Integer.parse(txindex)
    {oindex, _} = Integer.parse(oindex)
    block_height + txindex + oindex
  end

end

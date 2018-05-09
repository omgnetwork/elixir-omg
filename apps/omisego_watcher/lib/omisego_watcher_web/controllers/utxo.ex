defmodule OmiseGOWatcherWeb.Controller.Utxo do
  @moduledoc"""
  Operations related to utxo.
  Modify the state in the database.
  """
  alias OmiseGOWatcher.{Repo, UtxoDB, TransactionDB}

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

    composed_utxo_exit = UtxoDB.compose_utxo_exit(block_height, txindex, oindex)

    json(conn, composed_utxo_exit)

  end

end

defmodule OmiseGOWatcherWeb.Controller.Utxo do
  @moduledoc """
  Operations related to utxo.
  Modify the state in the database.
  """

  alias OmiseGO.JSONRPC
  alias OmiseGOWatcher.{Repo, UtxoDB}

  use OmiseGOWatcherWeb, :controller
  import Ecto.Query, only: [from: 2]

  def available(conn, %{"address" => address}) do
    {:ok, address_decode} = JSONRPC.Client.decode(:bitstring, address)
    utxos = Repo.all(from(tr in UtxoDB, where: tr.address == ^address_decode, select: tr))
    fields_names = List.delete(UtxoDB.field_names(), :address)

    json(conn, %{
      address: address,
      utxos: JSONRPC.Client.encode(Enum.map(utxos, &Map.take(&1, fields_names)))
    })
  end

  def compose_utxo_exit(conn, %{"block_height" => block_height, "txindex" => txindex, "oindex" => oindex}) do
    {block_height, _} = Integer.parse(block_height)
    {txindex, _} = Integer.parse(txindex)
    {oindex, _} = Integer.parse(oindex)

    composed_utxo_exit = UtxoDB.compose_utxo_exit(block_height, txindex, oindex)

    IO.inspect composed_utxo_exit
    json(conn, JSONRPC.Client.encode(composed_utxo_exit))
  end
end

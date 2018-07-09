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

    json(conn, %{
      address: address,
      utxos: JSONRPC.Client.encode(UtxoDB.get_utxo(address_decode))
    })
  end

  def compose_utxo_exit(conn, %{"block_height" => block_height, "txindex" => txindex, "oindex" => oindex}) do
    {block_height, _} = Integer.parse(block_height)
    {txindex, _} = Integer.parse(txindex)
    {oindex, _} = Integer.parse(oindex)

    composed_utxo_exit = UtxoDB.compose_utxo_exit(block_height, txindex, oindex)

    json(conn, JSONRPC.Client.encode(composed_utxo_exit))
  end
end

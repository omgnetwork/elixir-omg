defmodule OMG.Watcher.Web.View.Utxo do
  use OMG.Watcher.Web, :view

  alias OMG.Watcher.Web.Serializer
  alias OMG.API.Crypto

  def render("utxo_exit.json", %{utxo_exit: utxo_exit}) do
    t= Crypto.encode16(utxo_exit, [:proof, :sigs, :txbytes])
    |> Serializer.Response.serialize(:success)
  end

  def render("available.json", %{available: %{address: address, utxos: utxos}}) do
    %{
      address: address,
      utxos: Crypto.encode16(utxos, [:txbytes, :currency])
    }
    |> Serializer.Response.serialize(:success)
  end

end
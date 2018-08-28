defmodule OMG.Watcher.Web.View.Transaction do
  use OMG.Watcher.Web, :view

  alias OMG.Watcher.Web.Serializer
  alias OMG.API.Crypto

  def render("transaction.json", %{transaction: transaction}) do
    Crypto.encode16(transaction, ["txid", "cur12", "newowner1", "newowner2","sig1", "sig2", "spender1", "spender2"])
    |> Serializer.Response.serialize(:success)
  end

end
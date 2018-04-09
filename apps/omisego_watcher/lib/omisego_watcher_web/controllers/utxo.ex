defmodule OmiseGOWatcherWeb.Controller.Utxo do
  @moduledoc"""
  Operations related to utxo.
  Modify the state in the database.
  """
  alias OmiseGOWatcher.{Repo, UtxoDB}
  use OmiseGOWatcherWeb, :controller
  import Ecto.Query, only: [from: 2]

  def available(conn, %{"address" => address}) do
    utxos = Repo.all(from(tr in UtxoDB, where: tr.address == ^address, select: tr))
    fields_names = List.delete(UtxoDB.field_names(), :address)

    json(conn, %{
      address: address,
      utxos: Enum.map(utxos, &Map.take(&1, fields_names))
    })
  end
end

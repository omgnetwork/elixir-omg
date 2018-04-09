defmodule OmiseGOWatcherWeb.Controller.Transaction do
  @moduledoc """
  Operations related to transaction.
  """

  use OmiseGOWatcherWeb, :controller

  alias OmiseGOWatcher.{Repo, TransactionDB}

  @doc """
  Retrieves a specific transaction by id.
  """
  def get(conn, %{"id" => id}) do
    id
    |> TransactionDB.get
    |> respond_single(conn)
  end

  # Respond with a single transaction
  defp respond_single(%TransactionDB{} = transaction, conn), do: json(conn, transaction)

  # Responds when the transaction is not found
  defp respond_single(nil, conn), do: send_resp(conn, :not_found, "")
end

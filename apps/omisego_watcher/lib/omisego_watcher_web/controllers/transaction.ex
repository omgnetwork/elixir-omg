defmodule OmiseGOWatcherWeb.Controller.Transaction do
  @moduledoc """
  Operations related to transaction.
  """

  use OmiseGOWatcherWeb, :controller

  alias OmiseGOWatcher.{TransactionDB}

  @doc """
  Retrieves a specific transaction by id.
  """
  def get(conn, %{"id" => id}) do
    id
    |> Base.decode16!()
    |> TransactionDB.get()
    |> respond_single(conn)
  end

  # Respond with a single transaction
  defp respond_single(%TransactionDB{} = transaction, conn) do
    # TODO: do the encoding in a smarter way
    #       or just keep the binaries encoded in the database (increases disk footprint)
    transaction = %{
      transaction
      | txid: Base.encode16(transaction.txid),
        cur12: Base.encode16(transaction.cur12),
        newowner1: Base.encode16(transaction.newowner1),
        newowner2: Base.encode16(transaction.newowner2),
        sig1: Base.encode16(transaction.sig1),
        sig2: Base.encode16(transaction.sig2),
        spender1: transaction.spender1 && Base.encode16(transaction.spender1),
        spender2: transaction.spender2 && Base.encode16(transaction.spender2)
    }

    json(conn, transaction)
  end

  # Responds when the transaction is not found
  defp respond_single(nil, conn), do: send_resp(conn, :not_found, "")
end

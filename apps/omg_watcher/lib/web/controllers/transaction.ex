# Copyright 2018 OmiseGO Pte Ltd
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

defmodule OMG.Watcher.Web.Controller.Transaction do
  @moduledoc """
  Operations related to transaction.
  """

  use OMG.Watcher.Web, :controller

  alias OMG.Watcher.{TransactionDB}

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
    # FIXME: do the encoding in a smarter way
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

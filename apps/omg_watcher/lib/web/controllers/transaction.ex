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
  alias OMG.Watcher.Web.View

  import OMG.Watcher.Web.ErrorHandler

  @doc """
  Retrieves a specific transaction by id.
  """
  def get(conn, %{"id" => id}) do
    id
    |> Base.decode16!()
    |> TransactionDB.get()
    |> respond(conn)
  end

  defp respond(%TransactionDB{} = transaction, conn) do
    render(conn, View.Transaction, :transaction, transaction: transaction)
  end

  defp respond(nil, conn) do
    handle_error(conn, :transaction_not_found)
  end

end

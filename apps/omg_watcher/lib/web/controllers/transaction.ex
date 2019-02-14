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

  alias OMG.Watcher.API

  @doc """
  Retrieves a specific transaction by id.
  """
  def get_transaction(conn, params) do
    with {:ok, id} <- expect(params, "id", :hash) do
      id
      |> API.Transaction.get()
      |> api_response(conn, :transaction)
    end
  end

  @doc """
  Retrieves a list of transactions
  """
  def get_transactions(conn, params) do
    with {:ok, address} <- expect(params, "address", [:address, :optional]),
         {:ok, limit} <- expect(params, "limit", [:pos_integer, :optional]),
         {:ok, blknum} <- expect(params, "blknum", [:pos_integer, :optional]) do
      API.Transaction.get_transactions(address, blknum, limit)
      |> api_response(conn, :transactions)
    end
  end

  def submit(conn, params) do
    with {:ok, tx} <- expect(params, "transaction", :hex) do
      API.Transaction.submit(tx)
      |> api_response(conn, :submission)
    end
  end
end

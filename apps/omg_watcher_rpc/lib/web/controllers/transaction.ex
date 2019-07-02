# Copyright 2019 OmiseGO Pte Ltd
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

defmodule OMG.WatcherRPC.Web.Controller.Transaction do
  @moduledoc """
  Operations related to transaction.
  """

  use OMG.WatcherRPC.Web, :controller

  alias OMG.Utils.Metrics
  alias OMG.Watcher.API
  alias OMG.WatcherRPC.Web.Validator

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
    with {:ok, constraints} <- Validator.Constraints.parse(params) do
      API.Transaction.get_transactions(constraints)
      |> api_response(conn, :transactions)
    end
  end

  @doc """
  Submits transaction to child chain
  """
  def submit(conn, params) do
    with {:ok, tx} <- expect(params, "transaction", :hex) do
      API.Transaction.submit(tx)
      |> api_response(conn, :submission)
    end
    |> increment_metrics_counter()
  end

  @doc """
  Given token, amount and spender, finds spender's inputs sufficient to perform a payment.
  If also provided with receiver's address, creates and encodes a transaction.
  """
  def create(conn, params) do
    with {:ok, order} <- Validator.Order.parse(params) do
      API.Transaction.create(order)
      |> api_response(conn, :create)
    end
  end

  defp increment_metrics_counter(response) do
    case response do
      {:error, {:validation_error, _, _}} ->
        Metrics.increment("transaction.failed.validation", 1)

      %Plug.Conn{} ->
        Metrics.increment("transaction.succeed", 1)

      _ ->
        Metrics.increment("transaction.failed.unidentified", 1)
    end

    response
  end
end

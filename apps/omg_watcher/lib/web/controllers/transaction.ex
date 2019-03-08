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

  @doc """
  Given token, amount and spender, finds spender's inputs sufficient to perform a payment.
  If also provided with receiver's address, creates and encodes a transaction.
  """
  def create(conn, params) do
    with {:ok, order} <- parse_order(params) do
      API.Transaction.create(order)
      |> api_response(conn, :create)
    end
  end

  defp parse_order(params) do
    with {:ok, owner} <- expect(params, "owner", :address),
         {:ok, metadata} <- expect(params, "metadata", [:hash, :optional]),
         {:ok, raw_payments} <- expect(params, "payments", :list),
         {:ok, fee} <- parse_fee(Map.get(params, "fee", nil)),
         {:ok, payments} <- parse_payments(raw_payments) do
      {:ok,
       %{
         owner: owner,
         payments: payments,
         fee: fee,
         metadata: metadata
       }}
    end
  end

  defp parse_payments(raw_payments) do
    alias OMG.API.State.Transaction
    require Transaction

    payments =
      Enum.reduce_while(raw_payments, [], fn raw_payment, acc ->
        case parse_payment(raw_payment) do
          {:ok, payment} -> {:cont, acc ++ [payment]}
          error -> {:halt, error}
        end
      end)

    case payments do
      {:error, _} = validation_error -> validation_error
      payments when length(payments) <= Transaction.max_outputs() -> {:ok, payments}
      _ -> error("payments", {:too_many_payments, Transaction.max_outputs()})
    end
  end

  defp parse_payment(raw_payment) do
    with {:ok, owner} <- expect(raw_payment, "owner", :address),
         {:ok, amount} <- expect(raw_payment, "amount", :pos_integer),
         {:ok, currency} <- expect(raw_payment, "currency", :address),
         do: {:ok, %{owner: owner, currency: currency, amount: amount}}
  end

  defp parse_fee(map) when is_map(map) do
    with {:ok, currency} <- expect(map, "currency", :address),
         {:ok, amount} <- expect(map, "amount", :non_neg_integer),
         do: {:ok, %{currency: currency, amount: amount}}
  end

  defp parse_fee(_), do: error("fee", :missing)
end

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

defmodule OMG.Watcher.Web.Validator.Order do
  @moduledoc """
  Validates `/transaction.create` request body.
  """

  alias OMG.Watcher.UtxoSelection
  import OMG.RPC.Web.Validator.Base

  @doc """
  Parses and validates request body
  """
  @spec parse(map()) :: {:ok, UtxoSelection.order_t()} | {:error, any()}
  def parse(params) do
    with {:ok, owner} <- expect(params, "owner", :address),
         {:ok, metadata} <- expect(params, "metadata", [:hash, :optional]),
         {:ok, raw_payments} <- expect(params, "payments", :list),
         {:ok, fee} <- parse_fee(Map.get(params, "fee")),
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
    alias OMG.State.Transaction
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
    with {:ok, owner} <- expect(raw_payment, "owner", [:address, :optional]),
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

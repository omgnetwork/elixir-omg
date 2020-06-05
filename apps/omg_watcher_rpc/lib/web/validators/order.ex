# Copyright 2019-2020 OmiseGO Pte Ltd
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

defmodule OMG.WatcherRPC.Web.Validator.Order do
  @moduledoc """
  Validates `/transaction.create` request body.
  """

  require OMG.State.Transaction.Payment

  import OMG.Utils.HttpRPC.Validator.Base

  alias OMG.State.Transaction
  alias OMG.Utils.HttpRPC.Validator.Base
  alias OMG.WatcherInfo.UtxoSelection

  @doc """
  Parses and validates request body
  """
  @spec parse(map()) :: {:ok, UtxoSelection.order_t()} | Base.validation_error_t()
  def parse(params) do
    with {:ok, owner} <- expect(params, "owner", :address),
         {:ok, metadata} <- expect(params, "metadata", [:hash, :optional]),
         {:ok, fee} <- expect(params, "fee", map: &parse_fee/1),
         {:ok, payments} <- expect(params, "payments", list: &parse_payment/1),
         {:ok, payments} <- fills_in_outputs?(payments),
         :ok <- ensure_not_self_transaction(owner, payments) do
      {:ok,
       %{
         owner: owner,
         payments: payments,
         fee: fee,
         metadata: metadata
       }}
    end
  end

  defp ensure_not_self_transaction(owner, payments) when length(payments) > 0 do
    payments
    |> Enum.any?(fn payment ->
      owner != payment[:owner]
    end)
    |> handle_self_tx_result()
  end

  defp ensure_not_self_transaction(_, _), do: :ok

  defp handle_self_tx_result(true), do: :ok
  defp handle_self_tx_result(false), do: {:error, :self_transaction_not_supported}

  defp fills_in_outputs?(payments) do
    if length(payments) <= Transaction.Payment.max_outputs(),
      do: {:ok, payments},
      else: error("payments", {:too_many_payments, Transaction.Payment.max_outputs()})
  end

  defp parse_payment(raw_payment) do
    with {:ok, owner} <- expect(raw_payment, "owner", [:address, :optional]),
         {:ok, amount} <- expect(raw_payment, "amount", :pos_integer),
         {:ok, currency} <- expect(raw_payment, "currency", :address),
         do: {:ok, %{owner: owner, currency: currency, amount: amount}}
  end

  defp parse_fee(map) when is_map(map) do
    with {:ok, currency} <- expect(map, "currency", :address) do
      {:ok, %{currency: currency}}
    end
  end
end

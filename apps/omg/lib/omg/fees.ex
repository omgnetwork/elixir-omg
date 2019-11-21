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

defmodule OMG.Fees do
  @moduledoc """
  Transaction's fee validation functions.
  """

  alias OMG.MergeTransactionValidator
  alias OMG.State.Transaction
  alias OMG.Utxo

  require Utxo

  use OMG.Utils.LoggerExt

  @type fee_spec_t() :: %{token: Transaction.Payment.currency(), flat_fee: non_neg_integer}
  @type fee_t() :: %{Transaction.Payment.currency() => non_neg_integer} | :no_fees_required

  @doc ~S"""
  Checks whether the transaction's inputs cover the fees.

  ## Examples

      iex> Fees.covered?(%{"eth" => 2}, %{"eth" => 1, "omg" => 3})
      true

  """
  @spec covered?(implicit_paid_fee_by_currency :: map(), fees :: fee_t()) :: boolean()
  def covered?(_, :no_fees_required), do: true

  def covered?(implicit_paid_fee_by_currency, fees) do
    for {input_currency, implicit_paid_fee} <- implicit_paid_fee_by_currency do
      case Map.get(fees, input_currency) do
        nil -> false
        fee -> fee <= implicit_paid_fee
      end
    end
    |> Enum.any?()
  end

  @doc ~S"""
  Returns the fees to pay for a particular transaction,
  and under particular fee specs listed in `fee_map`.

  ## Examples

      iex> OMG.Fees.for_transaction(%OMG.State.Transaction.Recovered{}, %{"eth" => 1, "omg" => 3})
      %{"eth" => 1, "omg" => 3}

  """
  @spec for_transaction(Transaction.Recovered.t(), fee_t()) :: fee_t()
  def for_transaction(transaction, fee_map) do
    case MergeTransactionValidator.is_merge_transaction?(transaction) do
      true -> :no_fees_required
      false -> fee_map
    end
  end

  def to_api_format(fees) do
    Enum.map(fees, fn {currency,
                       %{
                         amount: amount,
                         pegged_currency: pegged_currency,
                         pegged_amount: pegged_amount,
                         pegged_stu: pegged_stu,
                         updated_at: updated_at
                       }} ->
      %{
        currency: currency,
        amount: amount,
        pegged_currency: {:skip_hex_encode, pegged_currency},
        pegged_amount: pegged_amount,
        pegged_subunit_to_unit: pegged_stu,
        updated_at: {:skip_hex_encode, updated_at}
      }
    end)
  end

  # empty list = no filter
  def filter_fees(fees, []), do: {:ok, fees}

  def filter_fees(fees, desired_currencies) do
    try do
      filterred_fees =
        Enum.into(desired_currencies, %{}, fn currency ->
          {currency, Map.fetch!(fees, currency)}
        end)

      {:ok, filterred_fees}
    rescue
      _error -> {:error, :currency_fee_not_supported}
    end
  end
end

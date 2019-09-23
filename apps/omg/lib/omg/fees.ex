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
  @type fee_t() :: %{Transaction.Payment.currency() => non_neg_integer} | :no_fees_transaction

  @doc """
  Checks whether the transaction's inputs cover the fees.
  """
  @spec covered?(implicit_paid_fee_by_currency :: map(), fees :: fee_t()) :: boolean()
  def covered?(_, :no_fees_transaction), do: true

  def covered?(implicit_paid_fee_by_currency, fees) do
    for {input_currency, implicit_paid_fee} <- implicit_paid_fee_by_currency do
      case Map.get(fees, input_currency) do
        nil -> false
        fee -> fee <= implicit_paid_fee
      end
    end
    |> Enum.any?()
  end

  @doc """
  Returns the fees to pay for a particular transaction,
  and under particular fee specs listed in `fee_map`.
  """
  @spec for_transaction(Transaction.Recovered.t(), fee_t()) :: fee_t()
  def for_transaction(transaction, fee_map) do
    case MergeTransactionValidator.is_merge_transaction?(transaction) do
      true ->
        :no_fees_transaction

      # TODO: reducing fees to output currencies only is incorrect, let's deffer until fees get large
      false ->
        fee_map
    end
  end
end

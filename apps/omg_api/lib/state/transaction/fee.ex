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

defmodule OMG.API.State.Transaction.Fee do
  @moduledoc """
  Provides Transaction's calculation
  """

  alias OMG.API.Crypto
  alias OMG.API.FeeChecker.Core
  alias OMG.API.State.Transaction

  @doc """
  Checks whether transaction's funds cover the fee
  """
  @spec covered?(Transaction.Recovered.t(), map(), map(), Core.token_fee_t()) :: boolean()
  def covered?(recovered_tx, input_amounts, output_amounts, fees) do
    fees = apply_fees(recovered_tx, Map.keys(input_amounts), fees)

    for {input_currency, input_amount} <- Map.to_list(input_amounts) do
      output_amount = Map.get(output_amounts, input_currency, 0)
      fee = Map.get(fees, input_currency, :infinity)
      input_amount - output_amount >= fee
    end
    |> Enum.any?()
  end

  # Processes fees for transaction, returns new fees that transaction is validated against.
  # Note: When transaction has no inputs in fee accepted currency, empty map is returned and transaction
  # will be rejected in `State.Core.exec`.
  # To make transaction fee free, zero-fee for transaction's currency needs to be explicitly returned.
  @spec apply_fees(Transaction.Recovered.t(), [Crypto.address_t()], Core.token_fee_t()) ::
          Core.token_fee_t()
  defp apply_fees(_recovered_tx, input_currencies, fees) do
    Map.take(fees, input_currencies)
  end
end

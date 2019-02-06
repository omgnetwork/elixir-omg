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
  alias OMG.API.FeeChecker
  alias OMG.API.State.Transaction

  @doc """

  """
  @spec apply(Transaction.Recovered.t(), [Crypto.address_t()], FeeChecker.Core.token_fee_t()) ::
          FeeChecker.Core.token_fee_t()
  def apply(_recovered_tx, input_currencies, fees) do
    tx_fees = Map.take(fees, input_currencies)

    if %{} == tx_fees,
      # transaction doesn't transfer any fee currency funds but still is obliged to pay a fee
      do: fees,
      else: tx_fees
  end
end

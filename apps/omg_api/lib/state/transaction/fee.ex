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
  alias OMG.API.State.Transaction

  @doc """
  Processes fees for transaction, returns new fees that transaction is validated against.
  Note: When transaction has no inputs in fee accepted currency, empty map is returned and transaction
  will be rejected in `State.Core.exec`.
  To make transaction fee free, zero-fee for transaction's currency needs to be explicitly returned.
  """
  @spec apply(Transaction.Recovered.t(), [Crypto.address_t()], OMG.API.FeeChecker.Core.token_fee_t()) ::
          FeeChecker.Core.token_fee_t()
  def apply(_recovered_tx, input_currencies, fees) do
    Map.take(fees, input_currencies)
  end
end

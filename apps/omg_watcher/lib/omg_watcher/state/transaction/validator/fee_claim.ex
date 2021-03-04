# Copyright 2019-2020 OMG Network Pte Ltd
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

defmodule OMG.Watcher.State.Transaction.Validator.FeeClaim do
  @moduledoc """
  Contains generic validation rules for `Transaction.Fee` transactions. Specific transaction type's validation
  is passed to `Transaction.Protocol.can_apply?`
  """

  alias OMG.Watcher.State.Core
  alias OMG.Watcher.State.Transaction

  @type fee_claim_error :: :surplus_in_token_not_collected | :claimed_and_collected_amounts_mismatch

  @spec can_claim_fees(Core.t(), Transaction.Recovered.t()) ::
          {:ok, %{}} | {{:error, fee_claim_error()}, Core.t()}
  def can_claim_fees(
        %Core{fee_claimer_address: owner, fees_paid: fees_paid} = state,
        %Transaction.Recovered{signed_tx: %{raw_tx: fee_tx}}
      ) do
    # NOTE: Fee claiming transaction does not transfer funds. It spends pseudo-output resultant of fees collection
    outputs = make_outputs(owner, fees_paid)

    case Transaction.Protocol.can_apply?(fee_tx, outputs) do
      {:ok, _} -> {:ok, %{}}
      {:error, _reason} = error -> {error, state}
    end
  end

  defp make_outputs(owner, fees_paid) do
    Enum.map(fees_paid, fn {currency, amount} ->
      Transaction.Fee.new_output(owner, currency, amount)
    end)
  end
end

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

defmodule OMG.State.Transaction.Validator do
  @moduledoc """
  Dispatches validation flow to payments application or fee claiming modules
  """

  require OMG.State.Transaction.Payment

  # FIXME: make it tighter `1 + #inputs` do the "Big Block test"
  # NOTE: Last processed transaction could potentially take his room but also generate `max_inputs` fee transactions
  @safety_margin 2 * OMG.State.Transaction.Payment.max_inputs()
  @maximum_block_size 65_536 - @safety_margin

  alias OMG.Fees
  alias OMG.State.Core
  alias OMG.State.Transaction
  alias OMG.State.Transaction.Validator

  @type can_process_tx_error ::
          :too_many_transactions_in_block | Validator.Payment.can_apply_error() | Validator.FeeClaim.fee_claim_error()

  @doc """
  Checks, whether at a given state of the ledger, a particular transaction can be applied (!) to it,
  subject to particular fee requirements
  """
  @spec can_process_tx(state :: Core.t(), tx :: Transaction.Recovered.t(), fees :: Fees.optional_fee_t()) ::
          {:ok, :apply_spend, map()} | {:ok, :claim_fees, map()} | {{:error, can_process_tx_error()}, Core.t()}
  def can_process_tx(%Core{} = state, %Transaction.Recovered{} = tx, fees) do
    with :ok <- validate_block_size(state), do: dispatch_validation(state, tx, fees)
  end

  defp validate_block_size(%Core{tx_index: number_of_transactions_in_block, fees_paid: fees_paid}) do
    fee_transactions_count = Enum.count(fees_paid)

    case number_of_transactions_in_block + fee_transactions_count >= @maximum_block_size do
      true -> {:error, :too_many_transactions_in_block}
      false -> :ok
    end
  end

  defp dispatch_validation(state, %Transaction.Recovered{signed_tx: %{raw_tx: %Transaction.Payment{}}} = tx, fees),
    do: Validator.Payment.can_apply_tx(state, tx, fees)

  defp dispatch_validation(
         state,
         %Transaction.Recovered{signed_tx: %{raw_tx: %Transaction.FeeTokenClaim{}}} = tx,
         _fees
       ),
       do: Validator.FeeClaim.can_claim_fees(state, tx)
end

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

defmodule OMG.State.Transaction.Validator.Payment do
  @moduledoc """
  Provides functions for stateful transaction validation for transaction processing in OMG.State.Core.
  Specific transaction type's validation is passed to `Transaction.Protocol.can_apply?`
  """

  alias OMG.Fees
  alias OMG.Output
  alias OMG.State.Core
  alias OMG.State.Transaction
  alias OMG.State.UtxoSet
  alias OMG.Utxo

  require Utxo

  @type can_apply_error ::
          :amounts_do_not_add_up
          | :fees_not_covered
          | :input_utxo_ahead_of_state
          | :unauthorized_spend
          | :utxo_not_found
          | :overpaying_fees
          | :multiple_potential_currency_fees

  @spec can_apply_tx(state :: Core.t(), tx :: Transaction.Recovered.t(), fees :: Fees.optional_fee_t()) ::
          {:ok, map()} | {{:error, can_apply_error()}, Core.t()}
  def can_apply_tx(
        %Core{utxos: utxos} = state,
        %Transaction.Recovered{signed_tx: %{raw_tx: raw_tx}, witnesses: witnesses} = tx,
        fees
      ) do
    inputs = Transaction.get_inputs(tx)

    with true <- not state.fee_claiming_started || {:error, :payments_rejected_during_fee_claiming},
         :ok <- inputs_not_from_future_block?(state, inputs),
         {:ok, outputs_spent} <- UtxoSet.get_by_inputs(utxos, inputs),
         :ok <- authorized?(outputs_spent, witnesses),
         {:ok, implicit_paid_fee_by_currency} <- Transaction.Protocol.can_apply?(raw_tx, outputs_spent),
         :ok <- Fees.check_if_covered(implicit_paid_fee_by_currency, fees) do
      {:ok, implicit_paid_fee_by_currency}
    else
      {:error, _reason} = error -> {error, state}
    end
  end

  defp inputs_not_from_future_block?(%Core{height: blknum}, inputs) do
    no_utxo_from_future_block =
      inputs
      |> Enum.all?(fn Utxo.position(input_blknum, _, _) -> blknum >= input_blknum end)

    if no_utxo_from_future_block, do: :ok, else: {:error, :input_utxo_ahead_of_state}
  end

  # Checks the outputs spent by this transaction have been authorized by correct witnesses
  @spec authorized?(list(Output.t()), list(Transaction.Witness.t())) ::
          :ok | {:error, :unauthorized_spend}
  defp authorized?(outputs_spent, witnesses) do
    outputs_spent
    |> Enum.with_index()
    |> Enum.map(fn {output_spent, idx} -> can_spend?(output_spent, witnesses[idx]) end)
    |> Enum.all?()
    |> if(do: :ok, else: {:error, :unauthorized_spend})
  end

  defp can_spend?(%OMG.Output{owner: owner}, witness), do: owner == witness
end

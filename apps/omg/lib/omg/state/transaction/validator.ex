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
  Provides functions for stateful transaction validation for transaction processing in OMG.State.Core.
  """

  require OMG.State.Transaction.Payment

  # NOTE: Last processed transaction could potentially take his room but also generate `max_inputs` fee transactions
  @safety_margin 2 * OMG.State.Transaction.Payment.max_inputs()
  @maximum_block_size 65_536 - @safety_margin

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
          | :too_many_transactions_in_block
          | :unauthorized_spend
          | :utxo_not_found
          | :overpaying_fees
          | :multiple_potential_currency_fees

  @type fee_claim_error :: :claiming_unsupported_token | :claiming_more_than_collected

  @type can_process_tx_error :: can_apply_error | fee_claim_error

  @doc """
  Checks, whether at a given state of the ledger, a particular transaction can be applied (!) to it,
  subject to particular fee requirements
  """
  @spec can_process_tx(state :: Core.t(), tx :: Transaction.Recovered.t(), fees :: Fees.optional_fee_t()) ::
          {:ok, :apply_spend, map()} | {:ok, :claim_fees, map()} | {{:error, can_process_tx_error()}, Core.t()}
  def can_process_tx(
        %Core{} = state,
        %Transaction.Recovered{signed_tx: %{raw_tx: raw_tx}} = tx,
        fees
      ) do
    case raw_tx do
      %Transaction.Payment{} ->
        can_apply_tx(state, tx, fees)

      %Transaction.FeeTokenClaim{} ->
        can_claim_fees(state, tx)
    end
  end

  @spec can_apply_tx(state :: Core.t(), tx :: Transaction.Recovered.t(), fees :: Fees.optional_fee_t()) ::
          {:ok, :apply_spend, map()} | {{:error, can_apply_error()}, Core.t()}
  defp can_apply_tx(
         %Core{utxos: utxos} = state,
         %Transaction.Recovered{signed_tx: %{raw_tx: raw_tx}, witnesses: witnesses} = tx,
         fees
       ) do
    inputs = Transaction.get_inputs(tx)

    with true <- not state.fee_claiming_started || {:error, :payments_rejected_during_fee_claiming},
         :ok <- validate_block_size(state),
         :ok <- inputs_not_from_future_block?(state, inputs),
         {:ok, outputs_spent} <- UtxoSet.get_by_inputs(utxos, inputs),
         :ok <- authorized?(outputs_spent, witnesses),
         {:ok, implicit_paid_fee_by_currency} <- Transaction.Protocol.can_apply?(raw_tx, outputs_spent),
         :ok <- Fees.check_if_covered(implicit_paid_fee_by_currency, fees) do
      {:ok, Fees.filter_fee_tokens(implicit_paid_fee_by_currency, fees)}
    else
      {:error, _reason} = error -> {error, state}
    end
  end

  @spec can_claim_fees(Core.t(), Transaction.Recovered.t()) ::
          {:ok, :claim_fees} | {{:error, fee_claim_error()}, Core.t()}
  defp can_claim_fees(
         %Core{fee_claimer_address: owner, fees_paid: fees_paid} = state,
         %Transaction.Recovered{signed_tx: %{raw_tx: fee_tx}}
       ) do
    with outputs = make_outputs(owner, fees_paid),
         {:ok, claimed_fee_token} <- Transaction.Protocol.can_apply?(fee_tx, outputs) do
      {:ok, :claim_fees, claimed_fee_token}
    else
      {:error, _reason} = error -> {error, state}
    end
  end

  defp make_outputs(owner, fees_paid) do
    Enum.map(fees_paid, fn {currency, amount} ->
      Transaction.FeeTokenClaim.new_output(owner, currency, amount)
    end)
  end

  defp validate_block_size(%Core{tx_index: number_of_transactions_in_block, fees_paid: fees_paid}) do
    fee_transactions_count = Enum.count(fees_paid)

    case number_of_transactions_in_block + fee_transactions_count >= @maximum_block_size do
      true -> {:error, :too_many_transactions_in_block}
      false -> :ok
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

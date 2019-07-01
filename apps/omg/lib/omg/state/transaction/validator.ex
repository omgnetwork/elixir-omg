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

defmodule OMG.State.Transaction.Validator do
  @moduledoc """
  Provides functions for stateful transaction validation for transaction processing in OMG.State.Core.

  """

  @maximum_block_size 65_536
  alias OMG.Fees
  alias OMG.State.Core
  alias OMG.State.Transaction
  alias OMG.Utxo
  require Utxo

  @type exec_error ::
          :amounts_do_not_add_up
          | :fees_not_covered
          | :input_utxo_ahead_of_state
          | :too_many_transactions_in_block
          | :unauthorized_spent
          | :utxo_not_found

  @spec can_apply_spend(state :: Core.t(), tx :: Transaction.Recovered.t(), fees :: Fees.fee_t()) ::
          true | {{:error, exec_error()}, Core.t()}
  def can_apply_spend(state, %Transaction.Recovered{} = tx, fees) do
    outputs = Transaction.get_outputs(tx)

    with :ok <- validate_block_size(state),
         {:ok, input_amounts_by_currency} <- correct_inputs?(state, tx),
         output_amounts_by_currency = get_amounts_by_currency(outputs),
         :ok <- amounts_add_up?(input_amounts_by_currency, output_amounts_by_currency),
         :ok <- transaction_covers_fee?(input_amounts_by_currency, output_amounts_by_currency, fees) do
      true
    else
      {:error, _reason} = error -> {error, state}
    end
  end

  defp validate_block_size(%Core{tx_index: number_of_transactions_in_block}) do
    case number_of_transactions_in_block == @maximum_block_size do
      true -> {:error, :too_many_transactions_in_block}
      false -> :ok
    end
  end

  defp correct_inputs?(%Core{utxos: utxos} = state, tx) do
    inputs = Transaction.get_inputs(tx)

    with :ok <- inputs_not_from_future_block?(state, inputs),
         {:ok, input_utxos} <- get_input_utxos(utxos, inputs),
         input_utxos_owners <- Enum.map(input_utxos, fn %{owner: owner} -> owner end),
         :ok <- Transaction.Recovered.all_spenders_authorized(tx, input_utxos_owners) do
      {:ok, get_amounts_by_currency(input_utxos)}
    end
  end

  defp get_amounts_by_currency(utxos) do
    utxos
    |> Enum.group_by(fn %{currency: currency} -> currency end, fn %{amount: amount} -> amount end)
    |> Enum.map(fn {currency, amounts} -> {currency, Enum.sum(amounts)} end)
    |> Map.new()
  end

  defp amounts_add_up?(input_amounts, output_amounts) do
    for {output_currency, output_amount} <- Map.to_list(output_amounts) do
      input_amount = Map.get(input_amounts, output_currency, 0)
      input_amount >= output_amount
    end
    |> Enum.all?()
    |> if(do: :ok, else: {:error, :amounts_do_not_add_up})
  end

  defp transaction_covers_fee?(input_amounts, output_amounts, fees) do
    Fees.covered?(input_amounts, output_amounts, fees)
    |> if(do: :ok, else: {:error, :fees_not_covered})
  end

  defp inputs_not_from_future_block?(%Core{height: blknum}, inputs) do
    no_utxo_from_future_block =
      inputs
      |> Enum.all?(fn Utxo.position(input_blknum, _, _) -> blknum >= input_blknum end)

    if no_utxo_from_future_block, do: :ok, else: {:error, :input_utxo_ahead_of_state}
  end

  defp get_input_utxos(utxos, inputs) do
    inputs
    |> Enum.reduce_while({:ok, []}, fn input, acc -> get_utxos(utxos, input, acc) end)
    |> reverse()
  end

  defp get_utxos(utxos, position, {:ok, acc}) do
    case Map.get(utxos, position) do
      nil -> {:halt, {:error, :utxo_not_found}}
      found -> {:cont, {:ok, [found | acc]}}
    end
  end

  @spec reverse({:ok, any()} | {:error, :utxo_not_found}) :: {:ok, list(any())} | {:error, :utxo_not_found}
  defp reverse({:ok, input_utxos}), do: {:ok, Enum.reverse(input_utxos)}
  defp reverse({:error, :utxo_not_found} = result), do: result
end

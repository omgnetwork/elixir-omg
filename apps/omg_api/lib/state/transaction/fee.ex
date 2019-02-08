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

  alias OMG.API.Fees
  alias OMG.API.State.Transaction
  alias OMG.API.Utxo

  require Utxo

  @doc """
  Checks whether transaction's funds cover the fee
  """
  @spec covered?(map(), map(), Fees.token_fee_t()) :: boolean()
  def covered?(input_amounts, output_amounts, fees) do
    for {input_currency, input_amount} <- Map.to_list(input_amounts) do
      # fee is implicit - it's the difference between funds owned and spend
      implicit_paid_fee = input_amount - Map.get(output_amounts, input_currency, 0)

      case Map.get(fees, input_currency) do
        nil -> false
        fee -> fee <= implicit_paid_fee
      end
    end
    |> Enum.any?()
  end

  @doc """
  Processes fees for transaction, returns new fees that transaction is validated against.
  Note: When transaction has no inputs in fee accepted currency, empty map is returned and transaction
  will be rejected in `State.Core.exec`.
  To make transaction fee free, zero-fee for transaction's currency needs to be explicitly returned.
  """
  @spec apply_fees(Transaction.Recovered.t(), Fees.token_fee_t()) :: Fees.token_fee_t()
  def apply_fees(
        %Transaction.Recovered{
          signed_tx: %Transaction.Signed{raw_tx: raw_tx}
        } = recovered_tx,
        fees
      ) do
    output_currencies = Transaction.get_currencies(raw_tx)

    if is_merge_transaction?(recovered_tx) do
      %{hd(output_currencies) => 0}
    else
      # TODO: reducing fees to output currencies only is incorrect, let's deffer until fees get large
      fees
    end
  end

  defp is_merge_transaction?(recovered_tx) do
    [
      &has_less_outputs_than_inputs?/1,
      &has_single_currency?/1,
      &has_same_account?/1
    ]
    |> juxt(recovered_tx)
    |> Enum.all?()
  end

  defp has_same_account?(%Transaction.Recovered{
         signed_tx: %Transaction.Signed{raw_tx: raw_tx},
         spenders: spenders
       }) do
    raw_tx
    |> Transaction.get_outputs()
    |> Enum.reject(&(&1.amount == 0))
    |> Enum.map(& &1.owner)
    |> Enum.concat(spenders)
    |> single?()
  end

  defp has_single_currency?(%Transaction.Recovered{
         signed_tx: %Transaction.Signed{raw_tx: raw_tx}
       }) do
    raw_tx
    |> Transaction.get_outputs()
    |> Enum.reject(&(&1.amount == 0))
    |> Enum.map(& &1.currency)
    |> single?()
  end

  defp has_less_outputs_than_inputs?(%Transaction.Recovered{
         signed_tx: %Transaction.Signed{raw_tx: raw_tx}
       }) do
    # we need to filter out placeholders
    inputs =
      Transaction.get_inputs(raw_tx)
      |> Enum.reject(&(&1 == Utxo.position(0, 0, 0)))

    outputs =
      Transaction.get_outputs(raw_tx)
      |> Enum.reject(&(&1.amount == 0))

    has_less_outputs_than_inputs?(inputs, outputs)
  end

  defp has_less_outputs_than_inputs?(inputs, outputs)
       when length(inputs) >= 1 and length(inputs) > length(outputs),
       do: true

  defp has_less_outputs_than_inputs?(_inputs, _outputs), do: false

  defp juxt(fs, arg), do: Enum.map(fs, fn f -> f.(arg) end)

  defp single?(list) do
    list
    |> Enum.dedup()
    |> (fn
          [_one] -> true
          _ -> false
        end).()
  end
end

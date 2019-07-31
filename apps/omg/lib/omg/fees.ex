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
  Transaction's fee validation functions
  """

  alias OMG.State.Transaction
  alias OMG.Utxo

  require Utxo

  use OMG.Utils.LoggerExt

  @type fee_spec_t() :: %{token: Transaction.currency(), flat_fee: non_neg_integer}
  @type fee_t() :: %{Transaction.currency() => non_neg_integer} | :ignore

  @doc """
  Checks whether transaction's funds cover the fee
  """
  @spec covered?(input_amounts :: map(), output_amounts :: map(), fees :: fee_t()) :: boolean()
  def covered?(_, _, :ignore), do: true

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
  Returns fees to require for a particular transaction, and under particular fee specs listed in `fee_map`
  """
  @spec for_tx(Transaction.Recovered.t(), fee_t()) :: fee_t()
  def for_tx(tx, fee_map) do
    if is_merge_transaction?(tx),
      do: :ignore,
      # TODO: reducing fees to output currencies only is incorrect, let's deffer until fees get large
      else: fee_map
  end

  defp is_merge_transaction?(recovered_tx) do
    [
      &has_less_outputs_than_inputs?/1,
      &has_single_currency?/1,
      &has_same_account?/1
    ]
    |> Enum.all?(fn predicate -> predicate.(recovered_tx) end)
  end

  defp has_same_account?(%Transaction.Recovered{spenders: spenders} = tx) do
    tx
    |> Transaction.get_outputs()
    |> Enum.map(& &1.owner)
    |> Enum.concat(spenders)
    |> single?()
  end

  defp has_single_currency?(tx) do
    tx
    |> Transaction.get_outputs()
    |> Enum.map(& &1.currency)
    |> single?()
  end

  defp has_less_outputs_than_inputs?(tx) do
    has_less_outputs_than_inputs?(
      Transaction.get_inputs(tx),
      Transaction.get_outputs(tx)
    )
  end

  defp has_less_outputs_than_inputs?(inputs, outputs), do: length(inputs) >= 1 and length(inputs) > length(outputs)

  defp single?(list), do: 1 == list |> Enum.dedup() |> length()
end

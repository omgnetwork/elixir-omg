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

  @type fee_spec_t() :: %{token: Transaction.Payment.currency(), flat_fee: non_neg_integer}
  @type fee_t() :: %{Transaction.Payment.currency() => non_neg_integer} | :ignore

  @doc """
  Checks whether transaction's funds cover the fee
  """
  @spec covered?(implicit_paid_fee_by_currency :: map(), fees :: fee_t()) :: boolean()
  def covered?(_, :ignore), do: true

  def covered?(implicit_paid_fee_by_currency, fees) do
    for {input_currency, implicit_paid_fee} <- implicit_paid_fee_by_currency do
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
      &is_payment?/1,
      &has_less_outputs_than_inputs?/1,
      &has_single_currency?/1,
      &has_same_account?/1
    ]
    |> Enum.all?(fn predicate -> predicate.(recovered_tx) end)
  end

  defp is_payment?(%Transaction.Recovered{signed_tx: %{raw_tx: %Transaction.Payment{}}}), do: true
  defp is_payment?(_), do: false

  defp has_same_account?(%Transaction.Recovered{witnesses: witnesses} = tx) do
    spenders = Map.values(witnesses)

    tx
    |> Transaction.Extract.get_outputs()
    |> Enum.map(& &1.owner)
    |> Enum.concat(spenders)
    |> single?()
  end

  defp has_single_currency?(tx) do
    tx
    |> Transaction.Extract.get_outputs()
    |> Enum.map(& &1.currency)
    |> single?()
  end

  defp has_less_outputs_than_inputs?(tx) do
    has_less_outputs_than_inputs?(
      Transaction.Extract.get_inputs(tx),
      Transaction.Extract.get_outputs(tx)
    )
  end

  defp has_less_outputs_than_inputs?(inputs, outputs), do: length(inputs) >= 1 and length(inputs) > length(outputs)

  defp single?(list), do: 1 == list |> Enum.dedup() |> length()
end

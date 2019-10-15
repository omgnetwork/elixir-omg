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

defmodule OMG.MergeTransactionValidator do
  @moduledoc """
  Decides whether transactions qualify as "merge" transactions that use a single currency,
  single recipient address and have fewer outputs than inputs. This decision is necessary
  to know by the child chain to not require the transaction fees.
  """

  alias OMG.Output
  alias OMG.State.Transaction
  alias OMG.Utxo

  require Utxo

  use OMG.Utils.LoggerExt

  @spec is_merge_transaction?(%Transaction.Recovered{}) :: boolean()
  def is_merge_transaction?(recovered_transaction) do
    [
      &is_payment?/1,
      &only_fungible_tokens?/1,
      &has_less_outputs_than_inputs?/1,
      &has_single_currency?/1,
      &has_same_account?/1
    ]
    |> Enum.all?(fn predicate -> predicate.(recovered_transaction) end)
  end

  defp is_payment?(%Transaction.Recovered{signed_tx: %{raw_tx: %Transaction.Payment{}}}), do: true
  defp is_payment?(_), do: false

  defp only_fungible_tokens?(tx),
    do: tx |> Transaction.get_outputs() |> Enum.all?(&match?(%Output.FungibleMoreVPToken{}, &1))

  defp has_same_account?(%Transaction.Recovered{witnesses: witnesses} = tx) do
    spenders = Map.values(witnesses)

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

  defp single?(list), do: 1 == list |> Enum.uniq() |> length()
end

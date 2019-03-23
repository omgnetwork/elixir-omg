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

defmodule OMG.State.PropTest.DoubleSpendTransaction do
  @moduledoc """
  Generates function needed to make transaction making double spend in propcheck test
  """
  use PropCheck
  alias OMG.PropTest.Generators
  alias OMG.PropTest.Helper
  alias OMG.State.PropTest

  defdelegate impl(tx, fee_map), to: PropTest.Transaction

  def args(%{model: %{history: history}}) do
    {unspend, spend} = Helper.get_utxos(history)
    available_currencies = Map.values(spend) |> Enum.map(& &1.currency) |> Enum.uniq()

    let [currency <- oneof(available_currencies)] do
      unspend = unspend |> Enum.filter(fn {_, %{currency: val}} -> val == currency end)
      spend = spend |> Enum.filter(fn {_, %{currency: val}} -> val == currency end)

      let [
        owners <- Generators.new_owners(),
        inputs <- Generators.input_transaction([List.first(spend) | unspend]),
        inputs_spend <- Generators.input_transaction(spend)
      ] do
        [
          PropTest.Transaction.prepare_args(Enum.take(inputs_spend ++ Enum.drop(inputs, 1), 2), owners),
          %{currency => 0}
        ]
      end
    end
  end

  @doc "check if any inputs utxo has been already spent"
  def pre(%{model: %{history: history}}, [{inputs, _, _}, _]) do
    {_, spend} = Helper.get_utxos(history)
    inputs |> Enum.any?(fn {position, _} -> Map.has_key?(spend, position) end)
  end

  def post(_state, _args, {:error, :utxo_not_found}), do: true

  def next(%{model: %{history: history, balance: balance} = model} = state, [transaction | _], _),
    do: %{state | model: %{model | history: [{:double_spend_transaction, transaction} | history], balance: balance}}

  defmacro __using__(_opt) do
    quote location: :keep do
      defcommand(:double_spend_transaction, do: unquote(Helper.create_delegate_to_defcommand(__MODULE__)))
    end
  end
end

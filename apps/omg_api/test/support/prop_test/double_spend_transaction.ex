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

defmodule OMG.API.State.PropTest.DoubleSpendTransaction do
  @moduledoc """
  Generator for Transaction to State
  """
  defmacro __using__(_opt) do
    quote location: :keep do
      defcommand :double_spend_transaction do
        alias OMG.API.LoggerExt
        alias OMG.API.State.PropTest
        alias OMG.API.State.PropTest.Generators
        alias OMG.API.State.PropTest.Helper
        alias OMG.API.State.Transaction

        def impl({inputs, currency_name, ouputs} = tr, fee_map) do
          StateCoreGS.exec(PropTest.Transaction.create(tr), PropTest.Transaction.create_fee_map(fee_map))
        end

        def args(%{model: %{history: history}}) do
          {unspend, spend} = Helper.get_utxos(history)
          available_currencies = Map.values(spend) |> Enum.map(& &1.currency) |> Enum.uniq()

          let [currency <- oneof(available_currencies)] do
            unspend = unspend |> Map.to_list() |> Enum.filter(fn {_, %{currency: val}} -> val == currency end)
            spend = spend |> Map.to_list() |> Enum.filter(fn {_, %{currency: val}} -> val == currency end)

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

        def pre(%{model: %{history: history}}, [{inputs, currency, output}, fee_map]) do
          {_, spend} = Helper.get_utxos(history)
          inputs |> Enum.any?(fn {position, _} -> Map.has_key?(spend, position) end)
        end

        def post(_state, args, {:error, _}), do: true

        def next(%{model: %{history: history, balance: balance} = model} = state, [transaction | _], ret) do
          %{state | model: %{model | history: [{:double_spend_transaction, transaction} | history], balance: balance}}
        end
      end
    end
  end
end

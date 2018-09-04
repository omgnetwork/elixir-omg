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

defmodule OMG.API.State.PropTest.Transaction do
  @moduledoc """
  Generator for Transaction to State
  """
  defmacro __using__(_opt) do
    quote location: :keep do
      defcommand :transaction do
        alias OMG.API.LoggerExt
        alias OMG.API.State.PropTest.Generators
        alias OMG.API.State.PropTest.Helper
        alias OMG.API.State.Transaction

        def impl({inputs, currency_name, ouputs} = tr, fee_map) do
          currency_map = Helper.currency()
          stable_entities = OMG.API.TestHelper.entities_stable()

          StateCoreGS.exec(
            OMG.API.TestHelper.create_recovered(
              inputs |> Enum.map(fn {position, owner} -> Tuple.append(position, Map.get(stable_entities, owner)) end),
              Map.get(currency_map, currency_name),
              ouputs |> Enum.map(fn {owner, amount} -> {Map.get(stable_entities, owner), amount} end)
            ),
            fee_map
            |> Enum.map(fn {currency_atom, cost} -> {Map.get(currency_map, currency_atom), cost} end)
            |> Map.new()
          )
        end

        def args(%{model: %{history: history}}) do
          spendable = Helper.spendable(history)
          available_currencies = Map.values(spendable) |> Enum.map(& &1.currency) |> Enum.uniq()

          let [
            currency <- oneof(available_currencies),
            inputs_size <- frequency([{1, 1}, {1, 2}]),
            new_owners <- Generators.new_owners()
          ] do
            spendable = spendable |> Map.to_list() |> Enum.filter(fn {_, %{currency: val}} -> val == currency end)

            let [
              inputs <- Generators.fixed_list(oneof(spendable), inputs_size),
              int_list <- Generators.fixed_list(choose(1, 30), length(new_owners))
            ] do
              total_amount = inputs |> Enum.map(fn {_, %{amount: amount}} -> amount end) |> Enum.sum()
              inputs = inputs |> Enum.map(fn {position, %{owner: owner}} -> {position, owner} end)
              divisor = Enum.sum(int_list)

              {[first | users_amount], use_amount} =
                Enum.map_reduce(int_list, 0, fn part, acc ->
                  amount = div(part * total_amount, divisor)
                  {amount, acc + amount}
                end)

              users_amount = [first + total_amount - use_amount | users_amount]

              output = Enum.zip(new_owners, users_amount)
              [{inputs, currency, output}, %{currency => 0}]
            end
          end
        end

        def pre(%{model: %{history: history}}, [{inputs, currency, output}, fee_map]) do
          spendable =
            Helper.spendable(history) |> Map.to_list() |> Enum.filter(fn {_, %{currency: val}} -> val == currency end)

          rich_inputs =
            inputs
            |> Enum.map(fn {position, _} -> Enum.find(spendable, &match?({^position, %{currency: currency}}, &1)) end)

          spend = output |> Enum.reduce(Map.get(fee_map, currency, 0), fn {_, amount}, acc -> acc + amount end)

          Map.has_key?(fee_map, currency) && Enum.all?(rich_inputs) &&
            Enum.reduce(rich_inputs, 0, fn {_, %{amount: amount}}, acc -> acc + amount end) >= spend
        end

        def post(_state, args, {:ok, _}), do: true

        def next(%{model: %{history: history, balance: balance} = model} = state, [transaction | _], ret) do
          %{state | model: %{model | history: [{:transaction, transaction} | history], balance: balance}}
        end
      end
    end
  end
end

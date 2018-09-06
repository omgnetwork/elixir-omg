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
  use OMG.API.LoggerExt
  alias OMG.API.State.PropTest.Helper

  def create({inputs, currency_name, future_owners}) do
    currency_map = Helper.currency()
    stable_entities = OMG.API.TestHelper.entities_stable()

    OMG.API.TestHelper.create_recovered(
      inputs |> Enum.map(fn {position, owner} -> Tuple.append(position, Map.get(stable_entities, owner)) end),
      Map.get(currency_map, currency_name),
      future_owners |> Enum.map(fn {owner, amount} -> {Map.get(stable_entities, owner), amount} end)
    )
  end

  def create_fee_map(fee_map) do
    currency_map = Helper.currency()

    fee_map
    |> Enum.map(fn {currency_atom, cost} -> {Map.get(currency_map, currency_atom), cost} end)
    |> Map.new()
  end

  def prepare_args(inputs, new_owners) do
    %{currency: currency} = inputs |> List.first() |> elem(1)
    total_amount = inputs |> Enum.map(fn {_, %{amount: amount}} -> amount end) |> Enum.sum()
    inputs = inputs |> Enum.map(fn {position, %{owner: owner}} -> {position, owner} end)
    divisor = Enum.reduce(new_owners, 0, fn {_, part}, acc -> acc + part end)

    {[{owner, amount} | users_amount], use_amount} =
      Enum.map_reduce(new_owners, 0, fn {owner, part}, acc ->
        amount = div(part * total_amount, divisor)
        {{owner, amount}, acc + amount}
      end)

    new_owners = [{owner, amount + total_amount - use_amount} | users_amount]
    {inputs, currency, new_owners}
  end

  defmacro __using__(_opt) do
    quote location: :keep do
      defcommand :transaction do
        alias OMG.API.LoggerExt
        alias OMG.API.State.PropTest
        alias OMG.API.State.PropTest.Generators
        alias OMG.API.State.PropTest.Helper
        alias OMG.API.State.Transaction

        def impl({inputs, currency_name, future_owners} = tr, fee_map) do
          StateCoreGS.exec(PropTest.Transaction.create(tr), PropTest.Transaction.create_fee_map(fee_map))
        end

        def args(%{model: %{history: history}}) do
          {unspent, _spent} = Helper.get_utxos(history)
          available_currencies = Map.values(unspent) |> Enum.map(& &1.currency) |> Enum.uniq()

          let [currency <- oneof(available_currencies)] do
            unspent = unspent |> Map.to_list() |> Enum.filter(fn {_, %{currency: val}} -> val == currency end)

            let [
              owners <- Generators.new_owners(),
              inputs <- Generators.input_transaction(unspent)
            ] do
              [
                PropTest.Transaction.prepare_args(inputs, owners),
                %{currency => 0}
              ]
            end
          end
        end

        def pre(%{model: %{history: history}}, [{inputs, currency, output}, fee_map]) do
          unspent =
            Helper.spendable(history) |> Map.to_list() |> Enum.filter(fn {_, %{currency: val}} -> val == currency end)

          rich_inputs =
            inputs
            |> Enum.map(fn {position, _} -> Enum.find(unspent, &match?({^position, %{currency: ^currency}}, &1)) end)

          spent_amount = output |> Enum.reduce(Map.get(fee_map, currency, 0), fn {_, amount}, acc -> acc + amount end)

          Map.has_key?(fee_map, currency) && Enum.all?(rich_inputs) &&
            Enum.reduce(rich_inputs, 0, fn {_, %{amount: amount}}, acc -> acc + amount end) >= spent_amount
        end

        def post(_state, args, {:ok, _}), do: true
        def post(_state, _args, _result), do: false

        def next(%{model: %{history: history, balance: balance} = model} = state, [transaction | _], ret) do
          %{state | model: %{model | history: [{:transaction, transaction} | history], balance: balance}}
        end
      end
    end
  end
end

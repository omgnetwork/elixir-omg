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

defmodule OMG.State.PropTest.Transaction do
  @moduledoc """
  Generates function needed to make correct transaction in propcheck test
  """
  use PropCheck
  alias OMG.PropTest.Constants
  alias OMG.PropTest.Generators
  alias OMG.PropTest.Helper
  alias OMG.Utxo
  require Constants
  require Utxo

  def normalize_variables({inputs, currency, future_owners}) do
    stable_entities = OMG.TestHelper.entities_stable()
    currency = Map.get(Constants.currencies(), currency)

    owners = Enum.map(inputs, fn {_, owner} -> Map.get(stable_entities, owner) end)

    {
      owners,
      inputs
      |> Enum.map(fn {Utxo.position(blknum, tx_index, oindex), _} ->
        {blknum, tx_index, oindex}
      end),
      future_owners
      |> Enum.map(fn {owner, amount} ->
        {Map.get(stable_entities, owner), currency, amount}
      end)
    }
  end

  def create(variable) do
    {input_owners, inputs, outputs} = normalize_variables(variable)

    OMG.TestHelper.create_recovered(
      input_owners,
      inputs,
      outputs
    )
  end

  def create_fee_map(fee_map) do
    fee_map
    |> Enum.map(fn {currency_atom, cost} -> {Map.get(Constants.currencies(), currency_atom), cost} end)
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

  def impl(tr, fee_map),
    do: OMG.State.PropTest.StateCoreGS.exec(create(tr), create_fee_map(fee_map))

  def args(%{model: %{history: history}}) do
    {unspent, _spent} = Helper.get_utxos(history)
    available_currencies = Map.values(unspent) |> Enum.map(& &1.currency) |> Enum.uniq()

    let [currency <- oneof(available_currencies)] do
      unspent = unspent |> Enum.filter(fn {_, %{currency: val}} -> val == currency end)

      let [
        owners <- Generators.new_owners(),
        inputs <- Generators.input_transaction(unspent)
      ] do
        [prepare_args(Enum.uniq(inputs), owners), %{currency => 0}]
      end
    end
  end

  @doc "check if all inputs exists and are valid, and its enough money for fee and outputs"
  def pre(%{model: %{history: history}}, [{inputs, currency, output}, fee_map]) do
    unspent = Helper.spendable(history) |> Enum.filter(fn {_, %{currency: val}} -> val == currency end)

    rich_inputs =
      inputs
      |> Enum.map(fn {position, _} -> Enum.find(unspent, &match?({^position, %{currency: ^currency}}, &1)) end)

    spent_amount = output |> Enum.reduce(Map.get(fee_map, currency, 0), fn {_, amount}, acc -> acc + amount end)

    Map.has_key?(fee_map, currency) && Enum.all?(rich_inputs) && length(inputs) == length(Enum.uniq(inputs)) &&
      Enum.reduce(rich_inputs, 0, fn {_, %{amount: amount}}, acc -> acc + amount end) >= spent_amount
  end

  def post(_state, _args, {:ok, _}), do: true

  def next(%{model: %{history: history, balance: balance} = model} = state, [transaction | _], _) do
    %{state | model: %{model | history: [{:transaction, transaction} | history], balance: balance}}
  end

  defmacro __using__(_opt) do
    quote location: :keep do
      defcommand(:transaction, do: unquote(Helper.create_delegate_to_defcommand(__MODULE__)))
    end
  end
end

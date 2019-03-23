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

defmodule OMG.State.PropTest.MutatedTransaction do
  @moduledoc """
  Generates function needed to make transaction with wrong some parameters in propcheck test
  """
  use PropCheck
  import PropCheck.BasicTypes
  alias OMG.PropTest.Constants
  alias OMG.PropTest.Generators
  alias OMG.PropTest.Helper
  alias OMG.State.PropTest
  alias OMG.State.Transaction
  alias OMG.Utxo
  require Constants
  require Utxo

  @proportion 10
  defdelegate impl(inputs, fee_map), to: PropTest.Transaction

  def increase_output({owner, amount}) do
    {owner, frequency([{@proportion, amount}, {1, Generators.add_random(amount, {1, 1000})}])}
  end

  def inputs_mutate({Utxo.position(blknum, txindex, oindex), owner}) do
    {Utxo.position(
       frequency([{@proportion, blknum}, {1, Generators.add_random(blknum, {-blknum, 1_000})}]),
       frequency([{@proportion, txindex}, {1, choose(0, 65_000)}]),
       frequency([{@proportion, oindex}, {1, oneof([0, 1])}])
     ), frequency([{@proportion, owner}, {1, oneof(OMG.TestHelper.entities_stable() |> Map.keys())}])}
  end

  def args(state) do
    let [[{inputs, currency, outputs}, fee_map] <- PropTest.Transaction.args(state)] do
      let [
        inputs <- Generators.fixed_list(&inputs_mutate/1, inputs),
        currency <- frequency([{@proportion, currency}, {1, oneof(Constants.currencies() |> Map.keys())}]),
        outputs <- Generators.fixed_list(&increase_output/1, outputs)
      ] do
        [{inputs, currency, outputs}, fee_map]
      end
    end
  end

  @doc """
  Check if Transaction.Recovered.recover_from validate transaction and PropTest.Transaction.pre invalidate transaction
  """
  def pre(state, [tx | _] = args) do
    create_signed = &OMG.TestHelper.create_signed/3

    {valid, _} =
      tx
      |> PropTest.Transaction.normalize_variables()
      |> (&apply(create_signed, Tuple.to_list(&1))).()
      |> Transaction.Recovered.recover_from()

    !PropTest.Transaction.pre(state, args) && valid == :ok
  end

  def post(_state, _args, {:error, _}), do: true

  def next(%{model: %{history: history, balance: balance} = model} = state, [transaction | _], _ret) do
    %{state | model: %{model | history: [{:mutated_transaction, transaction} | history], balance: balance}}
  end

  defmacro __using__(_opt) do
    quote location: :keep do
      defcommand(:mutated_transaction, do: unquote(Helper.create_delegate_to_defcommand(__MODULE__)))
    end
  end
end

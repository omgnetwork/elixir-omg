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

defmodule OMG.State.PropTest.DifferentSpenderTransaction do
  @moduledoc """
  Generates function needed to make transaction with wrong spender in propcheck test
  """
  use PropCheck
  alias OMG.PropTest.Generators
  alias OMG.PropTest.Helper
  alias OMG.State.PropTest

  defdelegate impl(input, fee_map), to: PropTest.Transaction
  def change_owner({position, _}), do: {position, Generators.entitie_atom()}

  def args(state) do
    let [[{inputs, currency, outputs}, fee_map] <- PropTest.Transaction.args(state)] do
      let [inputs <- Generators.fixed_list(&change_owner/1, inputs)] do
        [{inputs, currency, outputs}, fee_map]
      end
    end
  end

  @doc "check if any inputs has wrong spender"
  def pre(%{model: %{history: history}}, [{inputs, _, _}, _]) do
    {unspent, _spent} = Helper.get_utxos(history)

    inputs
    |> Enum.any?(fn {position, owner} ->
      Map.has_key?(unspent, position) && Map.get(unspent, position)[:owner] != owner
    end)
  end

  def post(_, _, {:error, :unauthorized_spent}), do: true

  def next(%{model: %{history: history, balance: balance} = model} = state, [transaction | _], _) do
    %{
      state
      | model: %{model | history: [{:different_spender_transaction, transaction} | history], balance: balance}
    }
  end

  defmacro __using__(_opt) do
    quote location: :keep do
      defcommand(:different_spender_transaction, do: unquote(Helper.create_delegate_to_defcommand(__MODULE__)))
    end
  end
end

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
defmodule OMG.State.PropTest.FormBlock do
  @moduledoc """
  Generates function needed to produce block in propcheck test
  """

  alias OMG.PropTest.Constants
  alias OMG.PropTest.Helper
  alias OMG.State
  require Constants

  def impl do
    State.PropTest.StateCoreGS.form_block(Constants.child_block_interval())
  end

  def post(%{model: %{history: history}}, [], {:ok, {_, transactions, _}}) do
    expected_transactions =
      history
      |> Enum.take_while(&(elem(&1, 0) != :form_block))
      |> Enum.filter(&(elem(&1, 0) == :transaction))
      |> Enum.map(&elem(&1, 1))
      |> Enum.reverse()

    transactions = transactions |> Enum.map(fn %{tx: tx} -> Helper.format_transaction(tx) end)
    expected_transactions == transactions
  end

  def next(%{model: %{history: history} = model, eth: %{blknum: number} = eth} = state, [], _) do
    blknum = div(number, Constants.child_block_interval()) * Constants.child_block_interval()

    %{
      state
      | eth: %{eth | blknum: blknum + Constants.child_block_interval()},
        model: %{model | history: [{:form_block, blknum} | history]}
    }
  end

  defmacro __using__(_opt) do
    quote [location: :keep], do: defcommand(:form_block, do: unquote(Helper.create_delegate_to_defcommand(__MODULE__)))
  end
end

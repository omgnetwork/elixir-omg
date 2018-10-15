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

defmodule OMG.API.State.PropTest.ExitUtxos do
  @moduledoc """
  Generates function needed to get out of their utxo
  """
  use PropCheck
  alias OMG.API.PropTest.Helper
  alias OMG.API.Utxo
  require Utxo

  def impl(exiting_utxos), do: OMG.API.State.PropTest.StateCoreGS.exit_utxos(exiting_utxos)

  def args(%{model: %{history: history}}) do
    spendable = Helper.spendable(history) |> Map.to_list()

    let(
      [{position, %{owner: owner}} <- oneof(spendable)],
      do: [[%{utxo_pos: Utxo.Position.encode(position), owner: Helper.get_addr(owner)}]]
    )
  end

  @doc "check if all exits are from valid utxo-s"
  def pre(%{model: %{history: history}}, [exits]) do
    spendable = Helper.spendable(history)

    Enum.all?(exits, fn %{utxo_pos: position, owner: owner} ->
      owner == Map.get(spendable, Utxo.Position.decode(position), nil)
    end)
  end

  def post(_, _, {:ok, _}), do: true

  def next(%{model: %{history: history, balance: balance} = model} = state, [exits], _) do
    delete_utxo =
      exits
      |> Enum.map(fn %{utxo_pos: position} -> Utxo.Position.decode(position) end)

    %{state | model: %{model | history: [{:exit, delete_utxo} | history], balance: balance}}
  end

  defmacro __using__(_opt) do
    quote do
      defcommand(:exit_utxos, do: unquote(Helper.create_delegate_to_defcommand(__MODULE__)))
    end
  end
end

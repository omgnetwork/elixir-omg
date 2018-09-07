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

defmodule OMG.API.State.PropTest.EveryoneExit do
  @moduledoc """
  Generator for Exit utxo to State for everyone
  """

  defmacro __using__(_opt) do
    quote location: :keep do
      defcommand :everyone_exit do
        alias OMG.API.PropTest.Generators
        alias OMG.API.PropTest.Helper
        alias OMG.API.State.Transaction
        alias OMG.API.Utxo
        alias OMG.API.Utxo.Position
        require Utxo

        def impl(exiting_utxos), do: StateCoreGS.exit_utxos(exiting_utxos)

        def args(%{model: %{history: history}}) do
          ret = [
            Helper.spendable(history)
            |> Map.to_list()
            |> Enum.map(fn {{blknum, txindex, oindex}, %{owner: owner}} ->
              %{utxo_pos: Utxo.Position.encode(Utxo.position(blknum, txindex, oindex)), owner: Helper.get_addr(owner)}
            end)
          ]

          ret
        end

        def post(_, _, {:ok, _}), do: true

        def next(
              %{model: %{history: history, balance: balance} = model, eth: %{blknum: number} = eth} = state,
              [exits],
              ret
            ) do
          delete_utxo =
            exits
            |> Enum.map(fn %{utxo_pos: position} ->
              {:utxo_position, blknum, txindex, oindex} = Utxo.Position.decode(position)
              {blknum, txindex, oindex}
            end)

          %{state | model: %{model | history: [{:everyone_exit, delete_utxo} | history], balance: balance}}
        end
      end
    end
  end
end

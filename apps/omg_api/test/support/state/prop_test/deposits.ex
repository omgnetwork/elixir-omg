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

defmodule OMG.API.State.PropTest.Deposits do
  @moduledoc """
  Generator for deposits utxo to State
  """
  defmacro __using__(_opt) do
    quote location: :keep do
      defcommand :deposits do
        alias OMG.API.PropTest.Generators
        alias OMG.API.PropTest.Helper

        def impl(deposits), do: StateCoreGS.deposit(deposits)

        def args(%{eth: %{blknum: blknum}} = str) do
          let [number_of_deposit <- integer(1, 3)] do
            [
              for number <- 1..number_of_deposit do
                let(
                  [
                    currency <- Generators.get_currency(),
                    %{addr: owner} <- Generators.entity(),
                    amount <- integer(10_000, 300_000)
                  ],
                  do: %{blknum: blknum + number, currency: currency, owner: owner, amount: amount}
                )
              end
            ]
          end
        end

        def pre(%{eth: %{blknum: blknum}}, [deposits]) do
          list_block = deposits |> Enum.map(fn %{blknum: blknum} -> blknum end)
          expected = for i <- (blknum + 1)..(blknum + length(deposits)), do: i
          rem(blknum, 1000) + length(deposits) < 1000 and expected == list_block
        end

        def post(_state, [arg], {:ok, {_, dp_update}}) do
          new_utxo =
            dp_update
            |> Enum.filter(fn
              {:put, :utxo, _} -> true
              _ -> false
            end)
            |> length

          length(arg) == new_utxo
        end

        def next(
              %{eth: %{blknum: blknum} = eth, model: %{history: history, balance: balance} = model} = state,
              [args],
              ret
            ) do
          new_balance = Enum.reduce(args, balance, fn %{amount: amount}, balance -> balance + amount end)

          %{
            state
            | eth: %{eth | blknum: blknum + length(args)},
              model: %{model | history: [{:deposits, Helper.format_deposits(args)} | history], balance: new_balance}
          }
        end
      end
    end
  end
end

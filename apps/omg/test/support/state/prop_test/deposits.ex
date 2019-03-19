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

defmodule OMG.State.PropTest.Deposits do
  @moduledoc """
  Generates function needed to place deposit in propcheck test
  """
  use PropCheck
  alias OMG.PropTest.Generators
  alias OMG.PropTest.Helper

  def impl(deposits), do: OMG.State.PropTest.StateCoreGS.deposit(deposits)

  def args(%{eth: %{blknum: blknum}}) do
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

  @doc "check if expected block has good blknum"
  def pre(%{eth: %{blknum: blknum}}, [deposits]) do
    list_block = deposits |> Enum.map(fn %{blknum: blknum} -> blknum end)
    expected = for i <- (blknum + 1)..(blknum + length(deposits)), do: i
    rem(blknum, 1000) + length(deposits) < 1000 and expected == list_block
  end

  def post(_state, [arg], {:ok, {_, db_update}}) do
    new_utxo =
      db_update
      |> Enum.filter(&match?({:put, :utxo, _}, &1))
      |> length

    length(arg) == new_utxo
  end

  def next(%{eth: %{blknum: blknum} = eth, model: %{history: history, balance: balance} = model} = state, [args], _) do
    new_balance = Enum.reduce(args, balance, fn %{amount: amount}, balance -> balance + amount end)

    %{
      state
      | eth: %{eth | blknum: blknum + length(args)},
        model: %{model | history: [{:deposits, Helper.format_deposits(args)} | history], balance: new_balance}
    }
  end

  defmacro __using__(_opt) do
    quote([location: :keep], do: defcommand(:deposits, do: unquote(Helper.create_delegate_to_defcommand(__MODULE__))))
  end
end

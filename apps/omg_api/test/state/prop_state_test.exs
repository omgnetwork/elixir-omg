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

defmodule OMG.API.State.PropTest do
  @moduledoc """
  propcheck see: https://github.com/alfert/propcheck
  important:
   - command can be added from diffrent file, by elixir "use" with a little macro magic.
     example:  new_comand.ex
       defmodule ModuleName do
         defmacro __using__(_opt) do
           # leave quote option for better debug information
           quote location: :keep do
             # more about defcommand is in statem_dsl.ex from propcheck
             defcommand :command_name do
             end
           end
         end
       end

     then in file where are propcheck test
     use ModuleName
   - function weight taking the current model state and returning
     a map of command and frequency pairs to be generated.
  """

  use PropCheck
  use PropCheck.StateM.DSL
  use ExUnit.Case
  use OMG.API.LoggerExt
  # commands import to test
  use OMG.API.State.PropTest.{FormBlock, Deposits, Transaction, ExitUtxos, EveryoneExit}

  alias OMG.API.State.Core
  alias OMG.API.State.PropTest.Helper

  require OMG.API.State.PropTest.Constants
  require OMG.API.BlackBoxMe

  OMG.API.BlackBoxMe.create(OMG.API.State.Core, StateCoreGS)

  def initial_state do
    {:ok, state} = Core.extract_initial_state([], 0, 0, 1000)
    StateCoreGS.set_state(state)

    %{
      model: %{history: [], balance: 0},
      eth: %{blknum: 0}
    }
  end

  def weight(%{model: %{history: history}}) do
    utxos_ethereum =
      Helper.spendable(history)
      |> Map.to_list()
      |> Enum.count(&match?({_, %{currency: :ethereum}}, &1))

    [
      deposits: 10_00,
      form_block: 1_00
    ] ++
      if utxos_ethereum > 4 do
        [
          transaction: min(div(utxos_ethereum, 2), 20) * 10_00 + 1,
          exit_utxos: max(div(utxos_ethereum, 10), 1) * 1_000,
          everyone_exit: max(div(utxos_ethereum, 10), 1) * 1_00
        ]
      else
        []
      end
  end

  property "OMG.API.State.Core prope check", numtests: 5, max_size: 100, start_size: 10 do
    forall cmds <- commands(__MODULE__) do
      trap_exit do
        %{history: history, result: result, state: _state, env: _env} = run_commands(cmds)
        history = List.first(history) |> elem(0) |> (fn value -> value[:model][:history] end).()

        (result == :ok)
        |> when_fail(
          (fn ->
             Logger.info("History: #{inspect(history)}")
             Logger.error("Result: #{inspect(result)}")
           end).()
        )
        |> collect(
          fn samples ->
            samples
            |> Enum.with_index(1)
            |> Enum.map(fn {history, index} ->
              test_information =
                history
                |> Enum.map(&elem(&1, 0))
                |> Enum.reduce(%{}, fn el, acc -> Map.put(acc, el, Map.get(acc, el, 0) + 1) end)

              IO.puts("#{index}) #{inspect(test_information)} ")
            end)
          end,
          history
        )
        |> aggregate(command_names(cmds))
      end
    end
  end
end

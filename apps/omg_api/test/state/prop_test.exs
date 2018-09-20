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
     More information in lib/statem_dsl.ex from propcheck.
     Function should be defined in module where we define property test.
  """

  use PropCheck
  use PropCheck.StateM.DSL
  use ExUnit.Case
  use OMG.API.LoggerExt

  # commands import to test
  use OMG.API.State.PropTest.{
    Deposits,
    DifferentSpenderTransaction,
    DoubleSpendTransaction,
    EveryoneExit,
    ExitUtxos,
    FormBlock,
    Transaction
  }

  alias OMG.API.PropTest.Helper
  alias OMG.API.State.Core

  require OMG.API.PropTest.Constants

  def initial_state do
    {:ok, state} = Core.extract_initial_state([], 0, 0, 1000)
    OMG.API.State.PropTest.StateCoreGS.set_state(state)

    %{
      model: %{history: [], balance: 0},
      eth: %{blknum: 0}
    }
  end

  def weight(%{model: %{history: history}}) do
    {unspent, spent} = Helper.get_utxos(history)

    utxos_eth =
      unspent
      |> Map.to_list()
      |> Enum.count(&match?({_, %{currency: :eth}}, &1))

    spent_utxo_eth =
      spent
      |> Map.to_list()
      |> Enum.count(&match?({_, %{currency: :eth}}, &1))

    [
      deposits: 10_00,
      form_block: 1_00
    ] ++
      if utxos_eth > 4 do
        [
          transaction: min(div(utxos_eth, 2), 20) * 10_000 + 1,
          different_spender_transaction: min(div(utxos_eth, 2), 20) * 10_000 + 1,
          exit_utxos: max(div(utxos_eth, 10), 1) * 10_000,
          everyone_exit: max(div(utxos_eth, 10), 1) * 1_000
        ]
      else
        []
      end ++
      if spent_utxo_eth > 4 do
        [
          double_spend_transaction: max(div(spent_utxo_eth, 10), 1) * 10_00
        ]
      else
        []
      end
  end

  def state_core_property_test do
    forall cmds <- commands(__MODULE__) do
      trap_exit do
        %{history: history, result: result, state: _state, env: _env} = run_commands(cmds)
        history = List.first(history) |> elem(0) |> (fn value -> value[:model][:history] end).()

        collect_printer = fn samples ->
          counting = fn el, acc -> Map.put(acc, el, Map.get(acc, el, 0) + 1) end

          samples
          |> Enum.with_index(1)
          |> Enum.map(fn {history, index} ->
            test_information =
              history
              |> Enum.map(&elem(&1, 0))
              |> Enum.reduce(%{}, counting)

            IO.puts("#{index}) #{inspect(test_information)} ")
          end)
        end

        (result == :ok)
        |> when_fail(
          (fn ->
             Logger.info("History: #{inspect(history)}")
             Logger.error("Result: #{inspect(result)}")
           end).()
        )
        |> collect(collect_printer, history)
        |> aggregate(command_names(cmds))
      end
    end
  end

  property "quick test of property test", [:quiet, numtests: 3, max_size: 100, start_size: 20] do
    state_core_property_test()
  end

  @tag :property
  property "OMG.API.State.Core prope check", numtests: 10, max_size: 200, start_size: 100 do
    state_core_property_test()
  end
end

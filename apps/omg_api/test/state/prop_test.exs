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
  # check if model don't change bilans of tokens (in brackets which commands are needed to detect this)

  * we do not create or destroy money (generate double spend transaction,
    generate wrong transaction with wrong input or output, generate good transaction with some mutation)
  * try spend already spent money (generate double spend transaction)
  * can't spend someone else money (generate transaction witch different spender)
  * block hash don't contain unwanted transaction (generate double spend transaction,
    generate transaction witch different spender, generate good transaction with some mutation)
  * two block don't contain this same transaction, condition after execution form_block detects this.
  * detect if in State is special output index which gives free money (generate good transaction with some mutation)
  * detect if in State is special blknum index which gives free money (generate good transaction with some mutation)
  * check if restart State don't lost data (restart command change State state witch init)

  propcheck see: [propcheck](https://github.com/alfert/propcheck)

  important:
   - command can be added from different file, by elixir ```use``` with a little macro magic.
     example:
  > new_comand.ex
       ```
       defmodule ModuleName do
         defmacro __using__(_opt) do
           # leave quote option for better debug information
           quote location: :keep do
             # more about [defcommand](https://hexdocs.pm/propcheck/PropCheck.StateM.DSL.html#defcommand/2)
             defcommand :command_name do
             end
           end
         end
       end
       ```
     then in file where are propcheck test
     ``` use ModuleName ```

   - function weight should be defined in module where we define property test.
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
    MutatedTransaction,
    Transaction
  }

  alias OMG.API.PropTest.Helper
  alias OMG.API.State.Core

  require OMG.API.PropTest.Constants

  def initial_state do
    %{
      model: %{history: [], balance: 0},
      eth: %{blknum: 0}
    }
  end

  @doc """
  Taking the current model state and returning
  a map of command and frequency pairs to be generated.
  More information in [statem_dsl.ex](https://github.com/alfert/propcheck/blob/master/lib/statem_dsl.ex#L245)
  """
  def weight(%{model: %{history: history}}) do
    {unspent, spent} = Helper.get_utxos(history)

    utxos_eth =
      unspent
      |> Enum.count(&match?({_, %{currency: :eth}}, &1))

    spent_utxo_eth =
      spent
      |> Enum.count(&match?({_, %{currency: :eth}}, &1))

    [
      deposits: 10_00,
      form_block: 1_00
    ] ++
      if utxos_eth > 4 do
        [
          transaction: min(div(utxos_eth, 2), 20) * 10_000 + 1,
          different_spender_transaction: min(div(utxos_eth, 2), 20) * 10_000 + 1,
          mutated_transaction: min(div(utxos_eth, 2), 20) * 5_000 + 1,
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

  defp print_collected_stats(samples) do
    count_occurrence = fn el, acc -> Map.put(acc, el, Map.get(acc, el, 0) + 1) end

    samples
    |> Enum.with_index(1)
    |> Enum.map(fn {history, index} ->
      test_information =
        history
        |> Enum.map(&elem(&1, 0))
        |> Enum.reduce(%{}, count_occurrence)

      Logger.info("#{index}) #{inspect(test_information)} ")
    end)
  end

  def state_core_property_test do
    forall cmds <- commands(__MODULE__) do
      trap_exit do
        {:ok, state} = Core.extract_initial_state([], 0, 0, 1000)
        OMG.API.State.PropTest.StateCoreGS.set_state(state)

        %{history: history, result: result, state: _state, env: _env} = run_commands(cmds)
        history = List.first(history) |> elem(0) |> (fn value -> value[:model][:history] end).()

        (result == :ok)
        |> when_fail(
          (fn ->
             Logger.info("History: #{inspect(history)}")
             Logger.error("Result: #{inspect(result)}")
           end).()
        )
        |> collect(&print_collected_stats/1, history)
        |> aggregate(command_names(cmds))
      end
    end
  end

  @tag capture_log: true
  property "quick test of property test", [:quiet, numtests: 10] do
    state_core_property_test()
  end

  @tag :property
  @tag timeout: 600_000
  property "OMG.API.State.Core prope check", numtests: 30_000 do
    state_core_property_test()
  end
end

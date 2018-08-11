# Copyright 2017 OmiseGO Pte Ltd
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

defmodule OmiseGO.API.State.PropTest do
  @moduledoc """
  Defines the state machine for chain state.
  """

  use PropCheck
  use PropCheck.StateM
  import PropCheck.BasicTypes
  use ExUnit.Case
  alias OmiseGO.API.State.Core
  alias OmiseGO.API.State.CoreGS
  @moduletag capture_log: true

  # TODO: make aggregation and statistics informative

  describe "core handles deposits" do
    property "quick test of property test", [:quiet, max_size: 100, numtests: 10] do
      do_core_handles_deposits()
    end

    @tag :property
    property "core handles deposits", [:verbose, max_size: 100] do
      do_core_handles_deposits()
    end
  end

  defp do_core_handles_deposits do
    forall cmds <- commands(__MODULE__) do
      trap_exit do
        init()
        {history, state, result} = run_commands(__MODULE__, cmds)
        CoreGS.reset()

        success = result == :ok

        success
        |> when_fail(
          IO.puts("""
          History: #{inspect(history, pretty: true)}
          State: #{inspect(state, pretty: true)}
          Result: #{inspect(result, pretty: true)}
          """)
        )
        |> aggregate(command_names(cmds))
        |> collect(length(cmds))
      end
    end
  end

  def init do
    {:ok, state} = Core.extract_initial_state([], 0, 0, 1000)
    {:ok, :state_managed_by_helper} = CoreGS.init(state)
  end

  ##############
  # generators #
  ##############

  def deposit(blknum) do
    let [owner <- address(), amount <- pos_integer()] do
      %{
        blknum: blknum,
        # currency
        currency: <<0::160>>,
        # owner
        owner: owner,
        # amount
        amount: amount
      }
    end
  end

  def address do
    addresses =
      OmiseGO.API.TestHelper.entities()
      |> Map.split([:stable_alice, :stable_bob, :stable_mallory])
      |> elem(0)
      |> Map.values()
      |> Enum.map(&Map.get(&1, :addr))

    oneof(addresses)
  end

  ###########
  # helpers # (to be replaced by other moving parts of the system)
  ###########

  # Commands (alias, wrappers, etc)

  def exec(utxo1, utxo2, newowner1, newowner2, split) do
    outs = outputs(utxo1, utxo2, keypair(newowner1), keypair(newowner2), split)
    ins = tagged_inputs([utxo1, utxo2])
    rec = OmiseGO.API.TestHelper.create_recovered(ins, <<0::160>>, outs)
    CoreGS.exec(rec, %{<<0::160>> => 0})
  end

  #############
  # callbacks #
  #############

  defp exec_call(spendable_map) do
    spendable = Map.to_list(spendable_map)

    [
      {:call, __MODULE__, :exec,
       [oneof(spendable), oneof([nil, oneof(spendable)]), address(), address(), float(0.0, 1.0)]}
    ]
  end

  def command({model, eth}) do
    spendable_map =
      model.history
      |> spendable()

    tx =
      case map_size(spendable_map) > 0 do
        true ->
          exec_call(spendable_map)

        false ->
          []
      end

    deposit =
      case eth.blknum - eth.blknum / 1000 != 999 do
        true -> [{:call, CoreGS, :deposit, [[deposit(eth.blknum + 1)]]}]
        false -> []
      end

    rest = [
      {:call, CoreGS, :form_block, [1000]}
      # {:call, CoreGS, :exit_utxos, [[exit_utxo()]]},
    ]

    oneof(tx ++ deposit ++ rest)
  end

  def initial_state do
    # Child Chain model
    model = %{
      # historical transactions, young first
      # [{:tx, [input, ...], [output, ...]}, ...]
      history: [],
      txindex: 0
    }

    # Ethereum state
    eth = %{blknum: 0}
    {model, eth}
  end

  def next_state({model, eth}, _, {_, _, :form_block, _}) do
    {%{model | txindex: 0}, %{eth | blknum: next_blknum(eth.blknum)}}
  end

  def next_state({model, eth}, _, {_, _, :deposit, [[deposit]]}) do
    {position, value} = dep_to_utxo(deposit)
    model = %{model | history: [{:tx, [], [{position, value}]} | model.history]}
    {model, %{eth | blknum: deposit.blknum}}
  end

  def next_state({model, eth} = state, _, {_, _, :exec, [utxo1, utxo2, newowner1, newowner2, split]}) do
    case valid_utxos?(spendable(model.history), [utxo1, utxo2]) do
      true ->
        {new_utxo1, new_utxo2} =
          tx_to_utxo(next_blknum(eth.blknum), model.txindex, utxo1, utxo2, newowner1, newowner2, split)

        tx = {:tx, filter_zero_or_nil_utxo([utxo1, utxo2]), filter_zero_or_nil_utxo([new_utxo2, new_utxo1])}
        new_history = [tx | model.history]
        new_model = %{model | history: new_history, txindex: model.txindex + 1}
        {new_model, eth}

      _ ->
        state
    end
  end

  # tx should spent utxo known to model
  def precondition({model, _eth}, {_, _, :exec, [utxo1, utxo2, _, _, _]}) do
    spendable_map = spendable(model.history)

    non_zero_utxos?([utxo1, utxo2]) and valid_utxos?(spendable_map, [utxo1, utxo2])
  end

  def precondition(_model, _call), do: true

  # deposit is always successful and updates model
  def postcondition({_model, _eth}, {_, _, :deposit, [[_deposit]]}, result) do
    {:ok, {_event_triggers, db_updates}} = result
    length(db_updates) > 0
  end

  # spent is successful IFF utxos are known to model
  def postcondition({model, _eth}, {_, _, :exec, [utxo1, utxo2, _, _, _] = args}, result) do
    spendable = spendable(model.history)

    spent_ok = non_zero_utxos?([utxo1, utxo2]) and valid_utxos?(spendable, [utxo1, utxo2])

    case match?({:ok, _}, result) == spent_ok do
      true ->
        true

      false ->
        tagged = Enum.zip([:in1, :in2, :owner1, :owner2, :split], args)
        IO.puts("===============================")
        IO.puts("spendable is #{inspect(spendable(model.history))}")
        IO.puts("transaction is #{inspect(tagged)}")
        IO.puts("result is #{inspect(result)}")
        IO.puts("^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^")
        false
    end
  end

  def postcondition({_, _}, {_, _, :form_block, _}, {:ok, _}) do
    true
  end

  #############
  # utilities #
  #############

  defp spendable(history) do
    spendable(Enum.reverse(history), %{})
  end

  defp spendable([], unspent) do
    unspent
  end

  defp spendable([{:tx, inputs, outputs} | newer], unspent) do
    input_pos = inputs |> Enum.unzip() |> elem(0)
    unspent = unspent |> Map.split(input_pos) |> elem(1)
    unspent = Map.merge(unspent, Map.new(outputs))
    spendable(newer, unspent)
  end

  defp tagged_inputs(utxo_list) do
    utxo_list
    |> Enum.filter(&(&1 != nil))
    |> Enum.filter(&(&1 != {nil, nil}))
    |> Enum.map(fn {{blknum, txindex, oindex}, {owner_addr, _, _}} ->
      {blknum, txindex, oindex, keypair(owner_addr)}
    end)
  end

  defp non_zero_utxos?(list) when is_list(list) do
    Enum.all?(list, fn
      {_, {_, _, amount}} -> amount > 0
      nil -> true
    end)
  end

  defp filter_zero_or_nil_utxo(list) when is_list(list) do
    Enum.filter(list, fn
      {_, {_, _, amount}} -> amount > 0
      nil -> false
    end)
  end

  defp valid_utxos?(spendable, list) when is_list(list) do
    Enum.all?(list, &valid_utxo(spendable, &1))
  end

  defp valid_utxo(_, nil), do: true
  defp valid_utxo(spendable, {position, value}), do: value == Map.get(spendable, position, nil)

  defp dep_to_utxo(%{blknum: blknum, currency: currency, owner: owner, amount: amount}) do
    {{blknum, 0, 0}, {owner, currency, amount}}
  end

  defp tx_to_utxo(height, txindex, input1, nil, newowner1, newowner2, split) do
    tx_to_utxo(height, txindex, input1, {nil, {nil, nil, 0}}, newowner1, newowner2, split)
  end

  defp tx_to_utxo(height, txindex, {_pos1, {_, token, left}}, {_pos2, {_, _, right}}, newowner1, newowner2, split)
       when split >= 0 do
    {a1, a2} = split_to_amounts(left + right, split)
    {{{height, txindex, 0}, {newowner1, token, a1}}, {{height, txindex, 1}, {newowner2, token, a2}}}
  end

  defp split_to_amounts({_pos1, {_, _, left}}, nil, split) do
    split_to_amounts(left, split)
  end

  defp split_to_amounts({_pos1, {_, _, left}}, {_pos2, {_, _, right}}, split) do
    split_to_amounts(left + right, split)
  end

  defp split_to_amounts(sum, split) do
    amount1 = trunc(Float.ceil(sum * split))
    amount2 = sum - amount1
    {amount1, amount2}
  end

  defp outputs(utxo1, utxo2, newowner1, newowner2, split) do
    {a1, a2} = split_to_amounts(utxo1, utxo2, split)

    case newowner2 do
      nil -> [{newowner1, a1}]
      _ -> [{newowner1, a1}, {newowner2, a2}]
    end
  end

  defp next_blknum(blknum) do
    trunc(blknum / 1000) * 1000 + 1000
  end

  defp keypair(nil), do: nil
  defp keypair(<<0::160>>), do: nil

  defp keypair(addr) do
    OmiseGO.API.TestHelper.entities()
    |> Map.values()
    |> Enum.filter(fn map ->
      Map.get(map, :addr) == addr
    end)
    |> hd
  end
end

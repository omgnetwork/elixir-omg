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
  property "core handles deposits", [:verbose, max_size: 100] do
    forall cmds <- commands(__MODULE__) do
      trap_exit do
        init()
        r = run_commands(__MODULE__, cmds)
        {history, state, result} = r
        CoreGS.reset()

        (result == :ok)
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
      |> Enum.map(&(Map.get(&1, :addr)))
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

  defp exec_call(model) do
    history = Map.to_list(model.history)
    [{:call, __MODULE__, :exec, [oneof(history), oneof([nil, oneof(history)]), address(), address(), float(0.0, 1.0)]}]
  end

  def command({model, eth}) do
    tx =
      case map_size(model.utxos) > 0 do
        true ->
          exec_call(model)

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
      # spendable utxos: {blknum, txindex, oindex} => {owner, token, amount}
      utxos: %{},
      # historical utxos: {blknum, txindex, oindex} => {owner, token, amount}
      history: %{},
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
    model = %{model | utxos: Map.put(model.utxos, position, value), history: Map.put(model.history, position, value)}
    true = map_size(model.history) > 0
    {model, %{eth | blknum: deposit.blknum}}
  end

  def next_state({model, eth} = state, _, {_, _, :exec, [utxo1, utxo2, newowner1, newowner2, split]}) do
    case valid_utxos?(model, [utxo1, utxo2]) do
      true ->
        {{npos1, nval1}, {npos2, nval2}} =
          tx_to_utxo(next_blknum(eth.blknum), model.txindex, utxo1, utxo2, newowner1, newowner2, split)

        new_utxos =
          model.utxos
          |> Map.split(inputs([utxo1, utxo2]))
          |> elem(1)
          |> Map.merge(Map.new(filter_zero_or_nil_utxo([{npos1, nval1}, {npos2, nval2}])))

        new_history = Map.merge(model.history, Map.new([{npos1, nval1}, {npos2, nval2}]))
        new_model = %{model | utxos: new_utxos, history: new_history, txindex: model.txindex + 1}
        {new_model, eth}

      _ ->
        state
    end
  end

  # don't spent if deposits where not executed yet
  def precondition({%{utxos: utxos}, _eth}, {_, _, :exec, _}) when map_size(utxos) == 0, do: false
  # tx should spent utxo known to model
  def precondition({model, eth}, {_, _, :exec, [utxo1, utxo2, _, _, _]}) do
    non_zero_utxos?([utxo1, utxo2]) and valid_utxos?(model, [utxo1, utxo2]) and possible_utxos?(eth, [utxo1, utxo2])
  end

  def precondition(_model, _call), do: true

  # deposit is always successful and updates model
  def postcondition({_model, _eth}, {_, _, :deposit, [[_deposit]]}, result) do
    {:ok, {_event_triggers, db_updates}} = result
    length(db_updates) > 0
  end

  # spent is successful IFF utxos are known to model
  def postcondition({model, eth}, {_, _, :exec, [utxo1, utxo2, _, _, _] = args}, result) do
    spent_ok =
      non_zero_utxos?([utxo1, utxo2]) and valid_utxos?(model, [utxo1, utxo2]) and possible_utxos?(eth, [utxo1, utxo2])

    case match?({:ok, _}, result) == spent_ok do
      true ->
        true

      false ->
        IO.puts("===============================")
        IO.puts("model.utxos is #{inspect(model.utxos)}")
        IO.puts("transaction is #{inspect(args)}")
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

  defp inputs(utxo_list) do
    utxo_list
    |> Enum.filter(&(&1 != nil))
    |> Enum.filter(&(&1 != {nil, nil}))
    |> Enum.unzip()
    |> elem(0)
  end

  defp tagged_inputs(utxo_list) do
    utxo_list
    |> Enum.filter(&(&1 != nil))
    |> Enum.filter(&(&1 != {nil, nil}))
    |> Enum.map(fn({{blknum, txindex, oindex}, {owner_addr, _, _}}) ->
      {blknum, txindex, oindex, keypair(owner_addr)}
    end)
  end

  defp non_zero_utxos?(list) when is_list(list) do
    Enum.all?(list, fn
      {_, {_, _, x}} -> x > 0
      nil -> true
    end)
  end

  defp filter_zero_or_nil_utxo(list) when is_list(list) do
    Enum.filter(list, fn
      {_, {_, _, x}} -> x > 0
      nil -> false
    end)
  end

  def possible_utxos?(eth, list) when is_list(list) do
    Enum.all?(list, fn
      {{blknum, _, _}, _} -> blknum <= eth.blknum
      nil -> true
    end)
  end

  defp valid_utxos?(model, list) when is_list(list) do
    Enum.all?(list, &valid_utxo(model, &1))
  end

  defp valid_utxo(_, nil), do: true
  defp valid_utxo(model, {position, value}), do: value == Map.get(model.utxos, position, nil)

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
    |> Enum.filter(fn(map) ->
      Map.get(map, :addr) == addr
    end)
    |> hd
  end

end

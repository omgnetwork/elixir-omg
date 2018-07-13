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
  alias OmiseGO.API.State.Transaction
  alias OmiseGO.API.State.Transaction.Recovered
  @moduletag capture_log: true

  @tag :prop
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
        currency: :eth,
        # owner
        owner: owner,
        # amount
        amount: amount
      }
    end
  end

  def address do
    oneof([:alice, :bob, :carol, :mallory])
  end

  ###########
  # helpers # (to be replaced by other moving parts of the system)
  ###########

  # Commands (alias, wrappers, etc) (aliases are needed because of
  # limitations of generators).

  def eth_mine_block do
    CoreGS.form_block(1000)
  end

  def exec(utxo1, utxo2, newowner1, newowner2, split) do
    {_, {spender1, _, _}} = utxo1
    outs = outputs(utxo1, utxo2, newowner1, newowner2, split)
    tx =
      [utxo1, utxo2]
      |> inputs()
      |> Transaction.new(:eth, outs)
    rec = %Recovered{raw_tx: tx, spender1: spender1}
    rec = case utxo2 do
            nil -> rec
            {_, {spender2, _, _}} -> %{rec | spender2: spender2}
          end
    CoreGS.exec(rec, %{eth: 0})
  end

  #############
  # callbacks #
  #############

  def command({op, eth}) do
    history = Map.to_list(op.history)
    tx = case map_size(op.utxos) > 0 do
              true ->
                [{:call, __MODULE__, :exec, [
                     oneof(history),                 # input1
                     oneof([nil, oneof(history)]),   # input2
                     address(),                      # newowner1
                     address(),                      # newowner2
                     float(0.0, 1.0) # split between 1 and 2 IF newowner2 is non-zero
                   ]}]
              false -> []
            end
    deposit = case (eth.blknum - (eth.blknum / 1000)) != 999 do
                   true -> [{:call, CoreGS, :deposit, [[deposit(eth.blknum + 1)]]}]
                   false -> []
                 end
    rest = [
      {:call, __MODULE__, :eth_mine_block, []},
      # {:call, CoreGS, :exit_utxos, [[exit_utxo()]]},
    ]
    oneof(tx ++ deposit ++ rest)
  end

  def initial_state do
    op = %{utxos: %{},   # {blknum, txindex, oindex} => {owner, token, amount}
           history: %{}, # {blknum, txindex, oindex} => {owner, token, amount}
           txindex: 0}
    eth = %{blknum: 0}
    {op, eth}
  end

  defp next_blknum(blknum) do
    trunc(blknum / 1000) * 1000 + 1000
  end

  def next_state({op, eth}, _, {_, _, :eth_mine_block, _}) do
    {%{op | txindex: 0}, %{eth | blknum: next_blknum(eth.blknum)}}
  end

  def next_state({op, eth}, _, {_, _, :deposit, [[dep]]}) do
    {pos, value} = dep_to_utxo(dep)
    op = %{op | utxos: Map.put(op.utxos, pos, value),
           history: Map.put(op.history, pos, value)}
    true = map_size(op.history) > 0
    {op, %{eth | blknum: dep.blknum}}
  end

  def next_state({op, eth} = state, _, {_, _, :exec, [utxo1, utxo2, nwr1, nwr2, split]}) do
    case valid_utxos?(op, [utxo1, utxo2]) do
      true ->
        {{npos1, nval1}, {npos2, nval2}} =
          tx_to_utxo(next_blknum(eth.blknum), op.txindex, utxo1, utxo2, nwr1, nwr2, split)
        new_utxos =
          op.utxos
          |> Map.split(inputs([utxo1, utxo2]))
          |> elem(1)
          |> Map.merge(Map.new(filter_zero_or_nil_utxo([{npos1, nval1}, {npos2, nval2}])))
        new_history = Map.merge(op.history, Map.new([{npos1, nval1}, {npos2, nval2}]))
        new_op = %{op | utxos: new_utxos, history: new_history, txindex: op.txindex + 1}
        {new_op, eth}
      _ ->
        state
    end
  end

  # don't spent if deposits where not executed yet
  def precondition({%{utxos: utxos}, _eth}, {_, _, :exec, _}) when map_size(utxos) == 0, do: false
  # tx should spent utxo known to model
  def precondition({op, eth}, {_, _, :exec, [utxo1, utxo2, _, _, _]}) do
    non_zero_utxos?([utxo1, utxo2])
    and valid_utxos?(op, [utxo1, utxo2])
    and possible_utxos?(eth, [utxo1, utxo2])
  end
  def precondition(_model, _call), do: true

  # deposit is always successful and updates model
  def postcondition({_op, _eth}, {_, _, :deposit, [[_dep]]}, result) do
    {:ok, {_event_triggers, db_updates}} = result
    length(db_updates) > 0
  end

  # spent is successful IFF utxos are known to model
  def postcondition({op, eth}, {_, _, :exec, [utxo1, utxo2, _, _, _] = args}, result) do
    spent_ok = non_zero_utxos?([utxo1, utxo2])
               and valid_utxos?(op, [utxo1, utxo2])
               and possible_utxos?(eth, [utxo1, utxo2])
    case match?({:ok, _}, result) == spent_ok do
      true -> true
      false ->
        IO.puts("===============================")
        IO.puts("op.utxos is #{inspect op.utxos}")
        IO.puts("transaction is #{inspect args}")
        IO.puts("result is #{inspect result}")
        IO.puts("^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^")
        false
    end
  end

  def postcondition({_, _}, {_, _, :eth_mine_block, []}, {:ok, _}) do
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

  defp non_zero_utxos?(list) when is_list(list) do
    Enum.all?(list, fn
      ({_, {_, _, x}}) -> x > 0
      (nil) -> true
    end)
  end

  defp filter_zero_or_nil_utxo(list) when is_list(list) do
    Enum.filter(list, fn
      ({_, {_, _, x}}) -> x > 0
      (nil) -> false
    end)
  end

  def possible_utxos?(eth, list) when is_list(list) do
    Enum.all?(list, fn
      ({{blknum, _, _}, _}) -> blknum <= eth.blknum
      (nil) -> true
    end)
  end

  defp valid_utxos?(op, list) when is_list(list) do
    Enum.all?(list, &(valid_utxo(op, &1)))
  end
  defp valid_utxo(_, nil), do: true
  defp valid_utxo(op, {pos, value}), do: value == Map.get(op.utxos, pos, nil)


  defp dep_to_utxo(%{blknum: blknum, currency: currency, owner: owner, amount: amount}) do
    {{blknum, 0, 0}, {owner, currency, amount}}
  end

  defp tx_to_utxo(height, txindex, input1, nil, nwr1, nwr2, split) do
    tx_to_utxo(height, txindex, input1, {nil, {nil, nil, 0}}, nwr1, nwr2, split)
  end
  defp tx_to_utxo(height, txindex, {_pos1, {_, token, left}}, {_pos2, {_, _, right}}, nwr1, nwr2, split)
  when split >= 0 do
    {a1, a2} = split_to_amounts(left + right, split)
    {{{height, txindex, 0}, {nwr1, token, a1}},
     {{height, txindex, 1}, {nwr2, token, a2}}}
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

  ###########################
  # Testing the command generators and such
  ###########################

  @tag :gen_test
  test "commands produces something" do
    cmd_gen = commands(__MODULE__)
    size = 10
    {:ok, cmds} = produce(cmd_gen, size)

    assert is_list(cmds)

    first = hd(cmds)
    assert {:set, {:var, 1}, {:call, __MODULE__, _, _}} = first
  end
end

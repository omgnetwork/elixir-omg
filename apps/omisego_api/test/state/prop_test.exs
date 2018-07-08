defmodule OmiseGO.API.State.PropTest do
  @moduledoc """
  Defines the state machine for chain state.
  """

  use PropCheck
  use PropCheck.StateM
  use ExUnit.Case
  alias OmiseGO.API.State.Core
  alias OmiseGO.API.State.CoreGS
  alias OmiseGO.API.State.Transaction
  @moduletag capture_log: true

  @tag :prop
  property "core handles deposits", [:verbose, max_size: 100] do
    forall cmds <- more_commands(100, commands(__MODULE__)) do
      trap_exit do
        {:ok, state} = Core.extract_initial_state([], 0, 0, 1000)
        {:ok, :state_managed_by_helper} = CoreGS.init(state)
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

  # generators

  def address do
    entities = OmiseGO.API.TestHelper.entities()
    oneof([entities.stable_alice.addr,
           entities.stable_bob.addr,
           entities.stable_mallory.addr])
  end

  def deposit() do
    [%{
        blknum: pos_integer(),
        currency: <<0::size(160)>>,
        owner: address(),
        amount: integer()
     }]
  end

  # def tx() do
  #   %Transaction.Recovered{
  #     raw_tx: raw_tx,
  #     signed_tx_hash: _signed_tx_hash,
  #     spender1: spender1,
  #     spender2: spender2
  #   } = recovered_tx,
  # end

  # helpers (to be replaced by other moving parts of the system)

  # pseudo-action, all interesting stuff happens in next_state
  def eth_mine_block do
    :ok
  end

  # callbacks

  def command({_op, eth}) do
    oneof([
      {:call, __MODULE__, :eth_mine_block, []},
      {:call, CoreGS, :deposit, [deposit()]},
      # {:call, CoreGS, :exec, [tx()]},
      # {:call, CoreGS, :form_block, [1000]},
      # {:call, CoreGS, :exit_utxos, [[exit_utxo()]]},
    ])
  end

  def initial_state do
    op = %{utxos: []}
    eth = %{height: 1}
    {op, eth}
  end

  def next_state({op, eth}, _result, {_, _, :eth_mine_block, _}) do
    IO.puts("eth is #{inspect eth}")
    {op, %{eth | height: eth.height + 1}}
  end
  def next_state({op, eth}, _result, {_, _, :deposit, [dep]}) do
    op = %{op | utxos: [dep | op.utxos]}
    {op, eth}
  end

  # def precondition({_op, %{height: height}}, {_, _, :deposit, %{blknum: blknum}}) when height*1000 > blknum - 6000 do
  #   true
  # end
  # def precondition(_model, {_, _, :deposit, _}) do
  #   false
  # end
  def precondition(_model, _call) do
    true
  end

  def postcondition({_op, _eth}, _call, _result) do
    true
  end
end

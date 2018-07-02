defmodule OmiseGO.API.State.PropTest do
  @moduledoc """
  Defines the state machine for chain state.
  """

  use PropCheck
  use PropCheck.StateM
  use ExUnit.Case
  alias OmiseGO.API.State.Core
  alias OmiseGO.API.State.Transaction
  @moduletag capture_log: true

  defmodule Model do
    defstruct [
      :op,  # keeps state of SUT
      :eth, # state of Ethereum chain
    ]
  end

  @tag :prop
  property "core handles deposits", [:verbose, max_size: 100] do
    forall cmds <- more_commands(100, commands(__MODULE__)) do
      trap_exit do
        r = run_commands(__MODULE__, cmds)
        {history, state, result} = r
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

  def deposit(height) do
    %{
      blknum: height - 6000,
      currency: <<0::size(160)>>,
      owner: address(),
      amount: integer()
    }
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

  def command(model) do
    oneof([
      {:call, __MODULE__, :eth_mine_block, []},
      {:call, Core, :deposit, [deposit(model.eth.height), model.op]},
      # {:call, Core, :exec, [tx(), model.op]},
      # {:call, Core, :form_block, [model.op, 1000]},
      # {:call, Core, :exit_utxos, [[exit_utxo()], model.op]},
    ])
  end

  def initial_state do
    %Model{
      state: %Core{
        last_deposit_height: 1,
        utxos: []
      },
      op: %{
        utxos: []
      },
      eth: %{
        height: 1
      }
    }
  end

  def next_state(%OmiseGO.API.State.PropTest.Model{eth: eth} = model,
    _result,
    {_, _, :eth_mine_block, _}) do
    %{model | eth: %{eth | height: eth_height + 1}}
  end
  def next_state(model, _result, {_, _, :deposit, [dep, _]}) do
    %{model | }
  end

  def precondition(model, {_, _, :deposit, _}) # when height < 7
    do
    %Model{eth: %{:height => height}} = model
    IO.puts("height: #{inspect height}")
    height > 6
  end
  def precondition(_model, _call) do
    true
  end

  def postcondition(%Model{eth: _, op: %{height: height}}, _call, _result) do
    true
  end
end

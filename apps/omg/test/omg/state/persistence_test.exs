# Copyright 2019-2020 OmiseGO Pte Ltd
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

defmodule OMG.State.PersistenceTest do
  @moduledoc """
  Test focused on the persistence bits of `OMG.State.Core`
  """
  use ExUnitFixtures
  use ExUnit.Case, async: false
  use OMG.Utils.LoggerExt

  alias OMG.Block

  alias OMG.State.Transaction
  alias OMG.Utxo
  alias Support.WaitFor

  import OMG.TestHelper

  require Utxo

  @eth OMG.Eth.RootChain.eth_pseudo_address()
  @interval OMG.Eth.RootChain.get_child_block_interval() |> elem(1)
  @blknum1 @interval

  setup do
    db_path = Briefly.create!(directory: true)
    Application.put_env(:omg_db, :path, db_path, persistent: true)

    :ok = OMG.DB.init()
    {:ok, started_apps} = Application.ensure_all_started(:omg_db)
    {:ok, bus_apps} = Application.ensure_all_started(:omg_bus)

    {:ok, _} = Supervisor.start_link([{OMG.State, []}], strategy: :one_for_one)

    on_exit(fn ->
      Application.put_env(:omg_db, :path, nil)

      (started_apps ++ bus_apps)
      |> Enum.reverse()
      |> Enum.map(fn app -> :ok = Application.stop(app) end)
    end)

    {:ok, %{}}
  end

  @tag fixtures: [:alice, :bob]
  test "persists deposits and utxo is available after restart", %{alice: alice, bob: bob} do
    [
      %{owner: bob, currency: @eth, amount: 10, blknum: 1},
      %{owner: alice, currency: @eth, amount: 20, blknum: 2}
    ]
    |> persist_deposit()

    assert OMG.State.utxo_exists?(Utxo.position(2, 0, 0))

    :ok = restart_state()

    assert OMG.State.utxo_exists?(Utxo.position(1, 0, 0))
    assert OMG.State.utxo_exists?(Utxo.position(2, 0, 0))
  end

  @tag fixtures: [:alice]
  test "utxos are persisted", %{alice: alice} do
    [%{owner: alice, currency: @eth, amount: 20, blknum: 1}]
    |> persist_deposit()
    |> exec(create_recovered([{1, 0, 0, alice}], @eth, [{alice, 3}]))
    |> persist_form()

    assert not OMG.State.utxo_exists?(Utxo.position(1, 0, 0))
    assert OMG.State.utxo_exists?(Utxo.position(@blknum1, 0, 0))
  end

  @tag fixtures: [:alice, :bob]
  test "utxos are available after restart", %{alice: alice, bob: bob} do
    [%{owner: alice, currency: @eth, amount: 20, blknum: 1}]
    |> persist_deposit()
    |> exec(create_recovered([{1, 0, 0, alice}], @eth, [{bob, 7}, {alice, 3}]))
    |> exec(create_recovered([{@blknum1, 0, 0, bob}, {@blknum1, 0, 1, alice}], @eth, [{bob, 10}]))
    |> persist_form()

    :ok = restart_state()

    assert not OMG.State.utxo_exists?(Utxo.position(@blknum1, 0, 0))
    assert not OMG.State.utxo_exists?(Utxo.position(@blknum1, 0, 1))
    assert OMG.State.utxo_exists?(Utxo.position(@blknum1, 1, 0))
  end

  @tag fixtures: [:alice, :bob]
  test "cannot double spend from the transactions within the same block", %{alice: alice, bob: bob} do
    :ok = persist_deposit([%{owner: alice, currency: @eth, amount: 10, blknum: 1}])

    # after the restart newly up state won't have deposit's utxo in memory
    :ok = restart_state()

    assert :ok == exec(create_recovered([{1, 0, 0, alice}], @eth, [{bob, 7}, {alice, 3}]))
    assert :utxo_not_found == exec(create_recovered([{1, 0, 0, alice}], @eth, [{alice, 10}]))
  end

  @tag fixtures: [:alice]
  test "blocks and spends are persisted", %{alice: alice} do
    tx = create_recovered([{1, 0, 0, alice}], @eth, [{alice, 3}])

    [%{owner: alice, currency: @eth, amount: 20, blknum: 1}]
    |> persist_deposit()
    |> exec(tx)
    |> persist_form()

    assert {:ok, [hash]} = OMG.DB.block_hashes([@blknum1])

    :ok = restart_state()

    assert {:ok, [db_block]} = OMG.DB.blocks([hash])
    %Block{number: @blknum1, transactions: [block_tx], hash: ^hash} = Block.from_db_value(db_block)

    assert {:ok, tx} == Transaction.Recovered.recover_from(block_tx)

    assert {:ok, 1000} ==
             tx |> Transaction.get_inputs() |> hd() |> Utxo.Position.to_input_db_key() |> OMG.DB.spent_blknum()
  end

  @tag fixtures: [:alice]
  test "exiting utxo is deleted from state", %{alice: alice} do
    utxo_positions = [
      Utxo.position(@blknum1, 0, 0),
      Utxo.position(@blknum1, 0, 1)
    ]

    [%{owner: alice, currency: @eth, amount: 20, blknum: 1}]
    |> persist_deposit()
    |> exec(create_recovered([{1, 0, 0, alice}], @eth, [{alice, 3}]))
    |> persist_form()
    |> persist_exit_utxos(utxo_positions)

    :ok = restart_state()

    assert not OMG.State.utxo_exists?(Utxo.position(@blknum1, 0, 0))
    assert not OMG.State.utxo_exists?(Utxo.position(@blknum1, 0, 1))
  end

  @tag fixtures: [:alice]
  test "cannot spend just exited utxo", %{alice: alice} do
    :ok = persist_deposit([%{owner: alice, currency: @eth, amount: 20, blknum: 1}])

    {:ok, _, _} = OMG.State.exit_utxos([Utxo.position(1, 0, 0)])

    # exit db_updates won't get persisted yet, but alice tries to spent it immediately
    assert :utxo_not_found == exec(create_recovered([{1, 0, 0, alice}], @eth, [{alice, 20}]))

    # retry above with empty in-memory utxoset
    :ok = restart_state()

    {:ok, _, _} = OMG.State.exit_utxos([Utxo.position(1, 0, 0)])
    assert :utxo_not_found == exec(create_recovered([{1, 0, 0, alice}], @eth, [{alice, 20}]))
  end

  defp persist_deposit(deposits) do
    {:ok, db_updates} =
      deposits
      |> make_deposits()
      |> OMG.State.deposit()

    :ok = OMG.DB.multi_update(db_updates)
  end

  defp persist_form(:ok), do: persist_form()

  defp persist_form() do
    OMG.State.form_block()

    # because `form_block` is non-blocking operation we need to wait it finishes
    # easiest to do this is to schedule another operation on `OMG.State` which is blocking
    _ = OMG.State.utxo_exists?(Utxo.position(0, 0, 0))

    :ok
  end

  defp exec(:ok, tx), do: exec(tx)

  defp exec(tx) do
    case OMG.State.exec(tx, :no_fees_required) do
      {:ok, _} -> :ok
      {:error, reason} -> reason
    end
  end

  defp persist_exit_utxos(:ok, exit_infos), do: persist_exit_utxos(exit_infos)

  defp persist_exit_utxos(exit_infos) do
    {:ok, db_updates, _} = OMG.State.exit_utxos(exit_infos)

    :ok = OMG.DB.multi_update(db_updates)
  end

  defp make_deposits(list) do
    Enum.map(list, fn %{owner: owner, currency: currency, amount: amount, blknum: blknum} ->
      %{
        root_chain_txhash: <<blknum::256>>,
        log_index: 0,
        owner: owner.addr,
        currency: currency,
        amount: amount,
        blknum: blknum
      }
    end)
  end

  defp restart_state() do
    GenServer.stop(OMG.State)

    WaitFor.ok(fn -> if(GenServer.whereis(OMG.State), do: :ok) end)
    _ = Logger.info("OMG.State restarted")

    :ok
  end
end

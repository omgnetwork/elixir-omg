defmodule OmiseGO.DBTest do
  @moduledoc """
  A smoke test of the LevelDB support (temporary, remove if it breaks, and we have an all-omisego integration test)

  Note the excluded moduletag, this test requires an explicit `--include`

  NOTE: it broke, but fixed easily, still useful, since integration test is thin still
  """
  use ExUnitFixtures
  use ExUnit.Case, async: false

  alias OmiseGO.DB

  @moduletag :wrappers

  setup_all do
    {:ok, _} = Application.ensure_all_started(:briefly)
    :ok
  end

  setup do
    {:ok, dir} = Briefly.create(directory: true)

    {:ok, pid} =
      GenServer.start_link(
        OmiseGO.DB.LevelDBServer,
        %{db_path: dir},
        name: TestDBServer
      )

    on_exit(fn ->
      try do
        GenServer.stop(pid)
      catch
        :exit, _ -> :yeah_it_has_already_stopped
      end
    end)

    {:ok, %{dir: dir}}
  end

  test "handles block storage", %{dir: dir} do
    :ok =
      DB.multi_update(
        [
          {:put, :block, %{hash: "xyz"}},
          {:put, :block, %{hash: "vxyz"}},
          {:put, :block, %{hash: "wvxyz"}}
        ],
        TestDBServer
      )

    assert {:ok, [%{hash: "wvxyz"}, %{hash: "xyz"}]} == DB.blocks(["wvxyz", "xyz"], TestDBServer)

    :ok =
      DB.multi_update(
        [
          {:delete, :block, %{hash: "xyz"}}
        ],
        TestDBServer
      )

    checks = fn ->
      assert {:ok, [%{hash: "wvxyz"}, :not_found, %{hash: "vxyz"}]} == DB.blocks(["wvxyz", "xyz", "vxyz"], TestDBServer)
    end

    checks.()

    # check actual persistence
    restart(dir)
    checks.()
  end

  test "handles utxo storage and that it actually persists", %{dir: dir} do
    :ok =
      DB.multi_update(
        [
          {:put, :utxo, %{{10, 30, 0} => %{amount: 10, owner: "alice1"}}},
          {:put, :utxo, %{{11, 30, 0} => %{amount: 10, owner: "alice2"}}},
          {:put, :utxo, %{{11, 31, 0} => %{amount: 10, owner: "alice3"}}},
          {:put, :utxo, %{{11, 31, 1} => %{amount: 10, owner: "alice4"}}},
          {:put, :utxo, %{{50, 30, 0} => %{amount: 10, owner: "alice5"}}},
          {:delete, :utxo, {50, 30, 0}}
        ],
        TestDBServer
      )

    checks = fn ->
      assert {:ok,
              [
                %{{10, 30, 0} => %{amount: 10, owner: "alice1"}},
                %{{11, 30, 0} => %{amount: 10, owner: "alice2"}},
                %{{11, 31, 0} => %{amount: 10, owner: "alice3"}},
                %{{11, 31, 1} => %{amount: 10, owner: "alice4"}}
              ]} == DB.utxos(TestDBServer)
    end

    checks.()

    # check actual persistence
    restart(dir)
    checks.()
  end

  defp restart(dir) do
    :ok = GenServer.stop(TestDBServer)

    {:ok, _pid} =
      GenServer.start_link(
        OmiseGO.DB.LevelDBServer,
        %{db_path: dir},
        name: TestDBServer
      )
  end

  test "handles last exit height storage" do
    :ok =
      DB.multi_update(
        [
          {:put, :last_fast_exit_block_height, 12},
          {:put, :last_slow_exit_block_height, 10}
        ],
        TestDBServer
      )

    assert {:ok, 12} == DB.last_fast_exit_block_height(TestDBServer)
    assert {:ok, 10} == DB.last_slow_exit_block_height(TestDBServer)
  end
end

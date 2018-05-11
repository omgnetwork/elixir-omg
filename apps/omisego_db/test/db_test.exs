defmodule OmiseGO.DBTest do
  @moduledoc """
  A smoke test of the LevelDB support (temporary, remove if it breaks, and we have an all-omisego integration test)

  NOTE: it broke, but fixed easily, still useful, since integration test is thin still
  """
  use ExUnitFixtures
  use ExUnit.Case, async: false

  alias OmiseGO.DB

  setup do
    dir = Temp.mkdir!()

    {:ok, pid} =
      GenServer.start_link(
        OmiseGO.DB.LevelDBServer,
        %{db_path: dir},
        name: TestDBServer
      )

    on_exit(fn -> if Process.alive?(pid), do: :ok = GenServer.stop(TestDBServer), else: :ok end)
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
end

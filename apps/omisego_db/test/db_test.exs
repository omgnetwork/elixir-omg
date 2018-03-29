defmodule OmiseGO.DBTest do
  @moduledoc """
  A smoke test of the LevelDB support (temporary, remove if it breaks, and we have an all-omisego integration test)
  """
  use ExUnitFixtures
  use ExUnit.Case, async: false

  alias OmiseGO.DB

  setup do
    dir = Temp.mkdir!()
    {:ok, pid} = GenServer.start_link(
      OmiseGO.DB.LevelDBServer,
      %{db_path: dir},
      name: TestDBServer
    )
    on_exit fn -> if Process.alive?(pid), do: :ok = GenServer.stop(TestDBServer), else: :ok end
    {:ok, %{dir: dir}}
  end

  test "multiupdates, puts, deletes, gets txs and blocks" do

    :ok = DB.multi_update(
      [
        {:put, :tx, %{hash: "abcd"}},
        {:put, :tx, %{hash: "abcd"}},
        {:put, :tx, %{hash: "abcde"}},
      ],
      TestDBServer
    )
    assert {:ok, %{hash: "abcd"}} == DB.tx("abcd", TestDBServer)
    assert {:ok, %{hash: "abcde"}} == DB.tx("abcde", TestDBServer)
    assert {:ok, :not_found} == DB.tx("abcdef", TestDBServer)

    :ok = DB.multi_update(
      [
        {:put, :tx, %{hash: "abcdef"}},
        {:delete, :tx, "abcd"},
        {:put, :block, %{hash: "xyz"}},
        {:put, :block, %{hash: "vxyz"}},
        {:put, :block, %{hash: "wvxyz"}},
      ],
      TestDBServer
    )
    assert {:ok, :not_found} == DB.tx("abcd", TestDBServer)
    assert {:ok, %{hash: "abcde"}} == DB.tx("abcde", TestDBServer)
    assert {:ok, %{hash: "abcdef"}} == DB.tx("abcdef", TestDBServer)
    assert {:ok, [%{hash: "wvxyz"}, %{hash: "xyz"}]} ==
      DB.blocks(["wvxyz", "xyz"], TestDBServer)
  end

  test "check db actually does persist", %{dir: dir} do
    :ok = DB.multi_update([{:put, :tx, %{hash: "abcdef"}}], TestDBServer)
    :ok = GenServer.stop(TestDBServer)
    {:ok, _pid} = GenServer.start_link(
      OmiseGO.DB.LevelDBServer,
      %{db_path: dir},
      name: TestDBServer
    )
    assert {:ok, %{hash: "abcdef"}} == DB.tx("abcdef", TestDBServer)
  end

  test "handles utxo storage" do

    :ok = DB.multi_update(
      [
        {:put, :utxo, %{{10, 30, 0} => %{amount: 10, owner: "alice1"}}},
        {:put, :utxo, %{{11, 30, 0} => %{amount: 10, owner: "alice2"}}},
        {:put, :utxo, %{{11, 31, 0} => %{amount: 10, owner: "alice3"}}},
        {:put, :utxo, %{{11, 31, 1} => %{amount: 10, owner: "alice4"}}},
        {:put, :utxo, %{{50, 30, 0} => %{amount: 10, owner: "alice5"}}},
        {:delete, :utxo, {50, 30, 0}},
      ],
      TestDBServer
    )

    assert {:ok, [
      %{{10, 30, 0} => %{amount: 10, owner: "alice1"}},
      %{{11, 30, 0} => %{amount: 10, owner: "alice2"}},
      %{{11, 31, 0} => %{amount: 10, owner: "alice3"}},
      %{{11, 31, 1} => %{amount: 10, owner: "alice4"}},
    ]} == DB.utxos(TestDBServer)
  end
end

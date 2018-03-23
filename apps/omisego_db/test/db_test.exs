defmodule OmiseGO.DBTest do
  @moduledoc """
  A smoke test of the LevelDB support (temporary, remove if it breaks, and we have an all-omisego integration test)
  """
  use ExUnitFixtures
  use ExUnit.Case, async: false

  alias OmiseGO.DB

  setup do
    Exleveldb.destroy("/home/user/.omisego/data")
    {:ok, pid} = DB.start_link
    on_exit fn -> if Process.alive?(pid), do: :ok = DB.stop, else: :ok end
    :ok
  end

  test "multiupdates, puts, deletes, gets txs and blocks" do

    :ok = DB.multi_update(
      [
        {:put, :tx, %{hash: "abcd"}},
        {:put, :tx, %{hash: "abcd"}},
        {:put, :tx, %{hash: "abcde"}},
      ]
    )
    assert {:ok, %{"hash" => "abcd"}} == DB.tx(%{hash: "abcd"})
    assert {:ok, %{"hash" => "abcde"}} == DB.tx(%{hash: "abcde"})
    assert :not_found == DB.tx(%{hash: "abcdef"})

    :ok = DB.multi_update(
      [
        {:put, :tx, %{hash: "abcdef"}},
        {:delete, :tx, %{hash: "abcd"}},
        {:put, :block, %{hash: "xyz"}},
        {:put, :block, %{hash: "vxyz"}},
        {:put, :block, %{hash: "wvxyz"}},
      ]
    )
    assert :not_found == DB.tx(%{hash: "abcd"})
    assert {:ok, %{"hash" => "abcde"}} == DB.tx(%{hash: "abcde"})
    assert {:ok, %{"hash" => "abcdef"}} == DB.tx(%{hash: "abcdef"})
    assert {:ok, [{:ok, %{"hash" => "wvxyz"}}, {:ok, %{"hash" => "xyz"}}]} ==
      DB.blocks([%{hash: "wvxyz"}, %{hash: "xyz"}])
  end

  test "check db actually does persist" do
    :ok = DB.multi_update([{:put, :tx, %{hash: "abcdef"}}])
    :ok = DB.stop
    {:ok, _pid} = DB.start_link
    assert {:ok, %{"hash" => "abcdef"}} == DB.tx(%{hash: "abcdef"})
  end

  test "handles utxo storage" do

    :ok = DB.multi_update(
      [
        {:put, :utxo, %{{10, 30, 0} => %{amount: 10, owner: "alice1"}}},
        {:put, :utxo, %{{11, 30, 0} => %{amount: 10, owner: "alice2"}}},
        {:put, :utxo, %{{11, 31, 0} => %{amount: 10, owner: "alice3"}}},
        {:put, :utxo, %{{11, 31, 1} => %{amount: 10, owner: "alice4"}}},
        {:put, :utxo, %{{50, 30, 0} => %{amount: 10, owner: "alice5"}}},
        {:delete, :utxo, %{{50, 30, 0} => nil}},
      ]
    )

    assert {:ok, [
      %{{10, 30, 0} => %{"amount" => 10, "owner" => "alice1"}},
      %{{11, 30, 0} => %{"amount" => 10, "owner" => "alice2"}},
      %{{11, 31, 0} => %{"amount" => 10, "owner" => "alice3"}},
      %{{11, 31, 1} => %{"amount" => 10, "owner" => "alice4"}},
    ]} == DB.utxos
  end
end

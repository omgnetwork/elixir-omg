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

defmodule OMG.DBTest do
  @moduledoc """
  A smoke test of the LevelDB support. The intention here is to **only** test minimally, that the pipes work.

  For more detailed persistence test look for `...PersistenceTest` tests throughout the apps.

  Note the excluded moduletag, this test requires an explicit `--include wrappers`
  """
  use ExUnitFixtures
  use OMG.DB.RocksDBCase, async: false

  alias OMG.DB

  @moduletag :wrappers
  @moduletag :common
  @writes 10

  test "handles object storage", %{db_dir: dir, db_pid: pid} do
    :ok =
      DB.multi_update(
        [{:put, :block, %{hash: "xyz"}}, {:put, :block, %{hash: "vxyz"}}, {:put, :block, %{hash: "wvxyz"}}],
        pid
      )

    assert {:ok, [%{hash: "wvxyz"}, %{hash: "xyz"}]} == DB.blocks(["wvxyz", "xyz"], pid)

    :ok = DB.multi_update([{:delete, :block, "xyz"}], pid)

    checks = fn pid ->
      assert {:ok, [%{hash: "wvxyz"}, :not_found, %{hash: "vxyz"}]} == DB.blocks(["wvxyz", "xyz", "vxyz"], pid)
    end

    checks.(pid)

    # check actual persistence
    pid = restart(dir, pid)
    checks.(pid)
  end

  test "handles single value storage", %{db_dir: dir, db_pid: pid} do
    :ok = DB.multi_update([{:put, :last_exit_finalizer_eth_height, 12}], pid)

    checks = fn pid ->
      assert {:ok, 12} == DB.get_single_value(:last_exit_finalizer_eth_height, pid)
    end

    checks.(pid)
    # check actual persistence
    pid = restart(dir, pid)
    checks.(pid)
  end

  test "block hashes return the correct range", %{db_dir: _dir, db_pid: pid} do
    :ok =
      DB.multi_update(
        [
          {:put, :block, %{hash: "xyz", number: 1}},
          {:put, :block, %{hash: "vxyz", number: 2}},
          {:put, :block, %{hash: "wvxyz", number: 3}}
        ],
        pid
      )

    {:ok, ["xyz", "vxyz", "wvxyz"]} = OMG.DB.block_hashes([1, 2, 3], pid)
  end

  test "utxo can be fetched by utxo position", %{db_pid: pid} do
    index = 123
    item = {{index, index, index}, %{test: :crypto.strong_rand_bytes(index)}}
    db_writes = [{:put, :utxo, item}]
    :ok = write(db_writes, pid)
    assert {:ok, ^item} = DB.utxo({index, index, index}, pid)
  end

  test "utxo is not found by utxo position", %{db_pid: pid} do
    assert :not_found = DB.utxo({1, 0, 0}, pid)
  end

  test "if multi reading utxos returns writen results", %{db_dir: _dir, db_pid: pid} do
    db_writes = create_write(:utxo, pid)
    {:ok, utxos} = DB.utxos(pid)
    [] = utxos -- db_writes
  end

  test "if multi reading competitor infos returns writen results", %{db_dir: _dir, db_pid: pid} do
    db_writes = create_write(:competitor_info, pid)
    {:ok, competitors_info} = DB.competitors_info(pid)
    [] = competitors_info -- db_writes
  end

  describe "Multi-instance storage path" do
    test "create paths for correctly prefixed instances" do
      base_path = "/tmp"

      assert "#{base_path}/exit_processor" == DB.join_path(OMG.DB.Instance.ExitProcessor, base_path)
      assert "#{base_path}/default" == DB.join_path(OMG.DB.Instance.Default, base_path)
      assert "#{base_path}/omg_network" == DB.join_path(OMG.DB.Instance.OMGNetwork, base_path)
    end

    test "fails when instance incorrectly prefixed" do
      assert_raise MatchError, fn -> DB.join_path(OMG.DB.RocksDB, "/path") end
    end
  end

  describe "Preparing sane defaults for database" do
    @base_path "/db/path"
    @default_name OMG.DB.RocksDB.Server
    @default_instance_name OMG.DB.Instance.Default

    test "fails when db_path not set" do
      assert_raise KeyError, fn -> DB.prepare_args(instance: OMG.DB.Instance.Default) end
    end

    test "fails when instance is not correctly prefixed" do
      assert_raise MatchError, fn ->
        DB.prepare_args(db_path: @base_path, instance: OMG.DB.RocksDB)
      end
    end

    test "suplements path of default instance when instance not set" do
      assert [name: @default_name, db_path: "#{@base_path}/default"] == DB.prepare_args(db_path: @base_path)
    end

    test "provides default name for default db instance" do
      assert [name: @default_name, db_path: "#{@base_path}/default"] ==
               DB.prepare_args(db_path: @base_path, instance: @default_instance_name)
    end

    test "default instance name cannot be overwritten" do
      assert [name: @default_name, db_path: "#{@base_path}/default"] ==
               DB.prepare_args(db_path: @base_path, name: @default_instance_name)

      assert [name: @default_name, db_path: "#{@base_path}/default"] ==
               DB.prepare_args(db_path: @base_path, name: @default_instance_name, instance: @default_instance_name)
    end

    test "suplements path and overrides name for non-default instance" do
      assert [name: OMG.DB.Instance.ExitProcessor, db_path: "#{@base_path}/exit_processor"] ==
               DB.prepare_args(db_path: @base_path, instance: OMG.DB.Instance.ExitProcessor)
    end
  end

  defp create_write(:utxo = type, pid) do
    db_writes =
      Enum.map(1..@writes, fn index ->
        {:put, type, {{index, index, index}, %{test: :crypto.strong_rand_bytes(index)}}}
      end)

    :ok = write(db_writes, pid)
    get_raw_values(db_writes)
  end

  defp create_write(:competitor_info = type, pid) do
    db_writes = Enum.map(1..@writes, fn index -> {:put, type, {:crypto.strong_rand_bytes(index), index}} end)

    :ok = write(db_writes, pid)
    get_raw_values(db_writes)
  end

  defp write(db_writes, pid), do: OMG.DB.multi_update(db_writes, pid)
  defp get_raw_values(db_writes), do: Enum.map(db_writes, &elem(&1, 2))

  defp restart(dir, pid) do
    :ok = GenServer.stop(pid)
    name = :"TestDB_#{make_ref() |> inspect()}"
    {:ok, pid} = start_supervised(OMG.DB.child_spec(db_path: dir, name: name), restart: :temporary)
    pid
  end
end

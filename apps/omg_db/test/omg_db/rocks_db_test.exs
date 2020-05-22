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

defmodule OMG.RocksDBTest do
  @moduledoc """
  A smoke test of the RocksDB support. The intention here is to **only** test minimally, that the pipes work.

  For more detailed persistence test look for `...PersistenceTest` tests throughout the apps.

  Note the excluded moduletag, this test requires an explicit `--include wrappers`
  """
  use ExUnitFixtures
  use OMG.DB.RocksDBCase, async: false

  alias OMG.DB

  @moduletag :wrappers
  @moduletag :common
  @writes 10

  test "rocks db handles object storage", %{db_dir: dir, db_pid: pid} do
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

  test "rocks db handles single value storage", %{db_dir: dir, db_pid: pid} do
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

  describe "batch_get" do
    test "can get single data with the type and single specific key", %{db_dir: _dir, db_pid: pid} do
      type = :exit_info
      specific_key = {1, 1, 1}
      data = {specific_key, :crypto.strong_rand_bytes(123)}
      :ok = DB.multi_update([{:put, type, data}], pid)

      assert {:ok, [data]} == DB.batch_get(type, [specific_key], server: pid)
    end

    test "can get multiple data with the type and multiple specific keys", %{db_dir: _dir, db_pid: pid} do
      type = :exit_info
      specific_keys = [{1, 1, 1}, {2, 2, 2}]
      data_list = Enum.map(specific_keys, fn key -> {key, :crypto.strong_rand_bytes(123)} end)

      :ok =
        data_list
        |> Enum.map(fn data -> {:put, type, data} end)
        |> DB.multi_update(pid)

      assert {:ok, data_list} == DB.batch_get(type, specific_keys, server: pid)
    end
  end

  test "it can get all data with the type", %{db_dir: _dir, db_pid: pid} do
    db_writes = create_write(:utxo, pid)

    assert {:ok, db_writes} == DB.get_all_by_type(:utxo, server: pid)
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

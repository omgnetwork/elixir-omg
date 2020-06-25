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

defmodule OMG.DB.PaymentExitInfoTest do
  @moduledoc """
  A smoke test of the RocksDB implementation for PaymentExitInfo.

  Note the excluded moduletag, this test requires an explicit `--include wrappers`
  """
  use ExUnitFixtures
  use OMG.DB.RocksDBCase, async: false

  alias OMG.DB.Models.PaymentExitInfo

  @moduletag :wrappers
  @moduletag :common
  @writes 10

  describe "exit_info" do
    test "should return single exit info when given the utxo position", %{db_dir: _dir, db_pid: pid} do
      {utxo_pos, _} = db_write = :exit_info |> create_write(pid) |> Enum.at(0)

      {:ok, result} = PaymentExitInfo.exit_info(utxo_pos, pid)

      assert result == db_write
    end
  end

  describe "exit_infos" do
    test "should return empty list if given empty list of positions", %{db_dir: _dir, db_pid: pid} do
      _db_writes = create_write(:exit_info, pid)

      {:ok, exits} = PaymentExitInfo.exit_infos([], pid)

      assert exits == []
    end

    test "should return all exit infos with the given utxo positions", %{db_dir: _dir, db_pid: pid} do
      test_range = 0..Integer.floor_div(@writes, 2)

      db_writes = create_write(:exit_info, pid)
      sliced_db_writes = Enum.slice(db_writes, test_range)

      utxo_pos_list = Enum.map(sliced_db_writes, fn {utxo_pos, _} = _write -> utxo_pos end)

      {:ok, exits} = PaymentExitInfo.exit_infos(utxo_pos_list, pid)

      assert exits == sliced_db_writes
    end
  end

  describe "all_exit_infos" do
    test "should return all exit infos", %{db_dir: _dir, db_pid: pid} do
      db_writes = create_write(:exit_info, pid)
      {:ok, exits} = PaymentExitInfo.all_exit_infos(pid)
      assert exits == db_writes
    end
  end

  describe "all_in_flight_exits_infos" do
    test "should return all in-flight exits info", %{db_dir: _dir, db_pid: pid} do
      db_writes = create_write(:in_flight_exit_info, pid)
      {:ok, in_flight_exits_infos} = PaymentExitInfo.all_in_flight_exits_infos(pid)
      assert in_flight_exits_infos == db_writes
    end
  end

  defp create_write(:exit_info = type, pid) do
    db_writes =
      Enum.map(1..@writes, fn index -> {:put, type, {{index, index, index}, :crypto.strong_rand_bytes(index)}} end)

    :ok = write(db_writes, pid)
    get_raw_values(db_writes)
  end

  defp create_write(:in_flight_exit_info = type, pid) do
    db_writes = Enum.map(1..@writes, fn index -> {:put, type, {:crypto.strong_rand_bytes(index), index}} end)

    :ok = write(db_writes, pid)
    get_raw_values(db_writes)
  end

  defp write(db_writes, pid), do: OMG.DB.multi_update(db_writes, pid)
  defp get_raw_values(db_writes), do: Enum.map(db_writes, &elem(&1, 2))
end

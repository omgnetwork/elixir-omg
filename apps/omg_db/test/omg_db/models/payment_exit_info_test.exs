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

  alias OMG.DB.RocksDB.Models.PaymentExitInfo

  @moduletag :wrappers
  @moduletag :common
  @writes 10

  test "if single reading exit info returns writen results", %{db_dir: _dir, db_pid: pid} do
    {utxo_pos, _} = db_write = create_write(:exit_info, pid) |> Enum.at(0)

    {:ok, result} = PaymentExitInfo.exit_info(utxo_pos, pid)

    assert result == db_write
  end

  test "if multi reading exit infos returns writen results", %{db_dir: _dir, db_pid: pid} do
    db_writes = create_write(:exit_info, pid)
    {:ok, exits} = PaymentExitInfo.exit_infos(pid)
    # what we wrote and what we read must be equal
    [] = exits -- db_writes
  end

  test "if multi reading in flight exit infos returns writen results", %{db_dir: _dir, db_pid: pid} do
    db_writes = create_write(:in_flight_exit_info, pid)
    {:ok, in_flight_exits_infos} = PaymentExitInfo.in_flight_exits_info(pid)
    [] = in_flight_exits_infos -- db_writes
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

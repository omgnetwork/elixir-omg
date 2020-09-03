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

defmodule OMG.DB.ReleaseTasks.InitKeysWithValuesTest do
  use OMG.DB.RocksDBCase, async: false
  alias OMG.DB.ReleaseTasks.InitKeysWithValues
  alias OMG.DB.RocksDB

  test ":last_ife_exit_deleted_eth_height is set if it wasn't set previously", %{
    db_pid: db_server_name
  } do
    assert [] == InitKeysWithValues.load([], db_server_name: db_server_name)
    assert {:ok, 0} == RocksDB.get_single_value(:last_ife_exit_deleted_eth_height, db_server_name)
  end

  test "value under :last_ife_exit_deleted_eth_height is not changed if it wasn't set previously", %{
    db_pid: db_server_name
  } do
    initial_value = 5
    :ok = RocksDB.multi_update([{:put, :last_ife_exit_deleted_eth_height, initial_value}], db_server_name)
    assert [] == InitKeysWithValues.load([], db_server_name: db_server_name)
    assert {:ok, initial_value} == RocksDB.get_single_value(:last_ife_exit_deleted_eth_height, db_server_name)
  end
end

# Copyright 2018 OmiseGO Pte Ltd
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
  use OMG.DB.Case, async: true

  alias OMG.DB

  @moduletag :wrappers

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
      assert {:ok, 12} == DB.get_single_value(pid, :last_exit_finalizer_eth_height)
    end

    checks.(pid)
    # check actual persistence
    pid = restart(dir, pid)
    checks.(pid)
  end

  defp restart(dir, pid) do
    :ok = GenServer.stop(pid)
    {:ok, pid} = GenServer.start_link(OMG.DB.LevelDBServer, %{db_path: dir}, name: :"TestDB_#{make_ref() |> inspect()}")
    pid
  end
end

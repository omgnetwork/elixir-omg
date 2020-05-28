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

defmodule OMG.Watcher.API.StatusCacheTest do
  use ExUnit.Case, async: true

  alias __MODULE__.BusMock
  alias __MODULE__.IntegrationModuleMock
  alias OMG.Watcher.API.StatusCache
  alias OMG.Watcher.SyncSupervisork

  setup do
    _ =
      if :undefined == :ets.info(SyncSupervisor.status_cache()),
        do: :ets.new(SyncSupervisor.status_cache(), [:set, :public, :named_table, read_concurrency: true])

    :ok
  end

  describe "get/0" do
    test "read from set ets" do
      :ets.insert(SyncSupervisor.status_cache(), {:status, :yolo})
      :yolo = StatusCache.get()
      :ets.delete(SyncSupervisor.status_cache(), :status)
    end
  end

  describe "start_link/1" do
    test "process stands up and inserts data on block message" do
      {:ok, pid} =
        StatusCache.start_link(
          ets: SyncSupervisor.status_cache(),
          event_bus: BusMock,
          integration_module: IntegrationModuleMock
        )

      assert StatusCache.get() == %{41 => 42}
      :erlang.trace(pid, true, [:receive])
      Kernel.send(pid, {:internal_event_bus, :ethereum_new_height, 43})
      assert_receive {:trace, _, :receive, {:internal_event_bus, :ethereum_new_height, 43}}
      :erlang.trace(pid, false, [:receive])
      assert StatusCache.get() == %{43 => 42}
    end
  end

  defmodule IntegrationModuleMock do
    def get_status(eth_block_number) do
      {:ok, %{eth_block_number => 42}}
    end

    def get_ethereum_height() do
      {:ok, 42 - 1}
    end
  end

  defmodule BusMock do
    def subscribe(_, _) do
      :ok
    end
  end
end

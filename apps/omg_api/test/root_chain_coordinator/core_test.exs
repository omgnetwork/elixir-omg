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
defmodule OMG.API.RootChainCoordinator.CoreTest do
  use ExUnitFixtures
  use ExUnit.Case, async: true

  alias OMG.API.RootChainCoordinator.Core

  deffixture initial_state() do
    Core.init(
      %{
        :depositor => %{sync_mode: :sync_with_coordinator},
        :exiter => %{sync_mode: :sync_with_root_chain}
      },
      10
    )
  end

  @tag fixtures: [:initial_state]
  test "does not synchronize service that is not allowed", %{initial_state: state} do
    :service_not_allowed = Core.check_in(state, :c.pid(0, 1, 0), 10, :unallowed_service)
  end

  @tag fixtures: [:initial_state]
  test "synchronizes services", %{initial_state: state} do
    depositor_pid = :c.pid(0, 1, 0)
    exiter_pid = :c.pid(0, 2, 0)

    {:ok, state, []} = Core.check_in(state, exiter_pid, 1, :exiter)
    :nosync = Core.get_synced_height(state, depositor_pid)
    {:sync, 10} = Core.get_synced_height(state, exiter_pid)

    {:ok, state, [^depositor_pid, ^exiter_pid]} = Core.check_in(state, depositor_pid, 2, :depositor)
    {:sync, 2} = Core.get_synced_height(state, depositor_pid)
    {:sync, 10} = Core.get_synced_height(state, exiter_pid)

    {:ok, state, []} = Core.check_in(state, exiter_pid, 10, :exiter)
    {:sync, 3} = Core.get_synced_height(state, depositor_pid)
    {:sync, 10} = Core.get_synced_height(state, exiter_pid)
  end

  @tag fixtures: [:initial_state]
  test "deregisters and registers a service", %{initial_state: state} do
    depositor_pid = :c.pid(0, 1, 0)
    exiter_pid = :c.pid(0, 2, 0)

    {:ok, state, []} = Core.check_in(state, exiter_pid, 1, :exiter)
    {:ok, state, [^depositor_pid, ^exiter_pid]} = Core.check_in(state, depositor_pid, 1, :depositor)
    {:sync, 2} = Core.get_synced_height(state, depositor_pid)
    {:sync, 10} = Core.get_synced_height(state, exiter_pid)

    {:ok, state} = Core.check_out(state, depositor_pid)
    :nosync = Core.get_synced_height(state, depositor_pid)

    {:ok, state, [^depositor_pid, ^exiter_pid]} = Core.check_in(state, depositor_pid, 1, :depositor)
    {:sync, 2} = Core.get_synced_height(state, depositor_pid)
    {:sync, 10} = Core.get_synced_height(state, exiter_pid)
  end

  test "returns services to sync up only for the last service checking in at a given height" do
    depositor_pid = :c.pid(0, 1, 0)
    exiter_pid = :c.pid(0, 2, 0)
    block_getter_pid = :c.pid(0, 3, 0)

    state =
      Core.init(
        %{
          :depositor => %{},
          :exiter => %{},
          :block_getter => %{}
        },
        10
      )

    {:ok, state, []} = Core.check_in(state, exiter_pid, 1, :exiter)
    {:ok, state, []} = Core.check_in(state, depositor_pid, 1, :depositor)

    {:ok, _state, [^block_getter_pid, ^depositor_pid, ^exiter_pid]} =
      Core.check_in(state, block_getter_pid, 1, :block_getter)
  end

  @tag fixtures: [:initial_state]
  test "updates root chain height", %{initial_state: state} do
    depositor_pid = :c.pid(0, 1, 0)
    exiter_pid = :c.pid(0, 2, 0)

    {:ok, state, []} = Core.check_in(state, exiter_pid, 10, :exiter)
    {:ok, state, [^depositor_pid, ^exiter_pid]} = Core.check_in(state, depositor_pid, 10, :depositor)
    {:sync, 10} = Core.get_synced_height(state, depositor_pid)
    {:sync, 10} = Core.get_synced_height(state, exiter_pid)

    {:ok, state} = Core.update_root_chain_height(state, 11)
    {:sync, 11} = Core.get_synced_height(state, depositor_pid)
    {:sync, 11} = Core.get_synced_height(state, exiter_pid)

    {:ok, state} = Core.update_root_chain_height(state, 14)
    {:sync, 11} = Core.get_synced_height(state, depositor_pid)
    {:sync, 14} = Core.get_synced_height(state, exiter_pid)
  end
end

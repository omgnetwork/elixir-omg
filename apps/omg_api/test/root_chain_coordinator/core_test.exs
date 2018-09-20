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
    %Core{allowed_services: MapSet.new([:exiter, :depositer]), root_chain_height: 10}
  end

  @tag fixtures: [:initial_state]
  test "does not synchronize service that is not allowed", %{initial_state: state} do
    :service_not_allowed = Core.check_in(state, :c.pid(0, 1, 0), 10, :unallowed_service)
  end

  @tag fixtures: [:initial_state]
  test "synchronizes services", %{initial_state: state} do
    depositer_pid = :c.pid(0, 1, 0)
    exiter_pid = :c.pid(0, 2, 0)

    {:ok, state, []} = Core.check_in(state, exiter_pid, 1, :exiter)
    :nosync = Core.get_synced_height(state)

    {:ok, state, [^depositer_pid, ^exiter_pid]} = Core.check_in(state, depositer_pid, 2, :depositer)
    {:sync, 2} = Core.get_synced_height(state)

    {:ok, state, []} = Core.check_in(state, exiter_pid, 1, :exiter)
    {:sync, 2} = Core.get_synced_height(state)
    {:ok, state, [^depositer_pid, ^exiter_pid]} = Core.check_in(state, exiter_pid, 2, :exiter)
    {:sync, 3} = Core.get_synced_height(state)
  end

  @tag fixtures: [:initial_state]
  test "deregisters and registers a service", %{initial_state: state} do
    depositer_pid = :c.pid(0, 1, 0)
    exiter_pid = :c.pid(0, 2, 0)

    {:ok, state, []} = Core.check_in(state, exiter_pid, 1, :exiter)
    {:ok, state, [^depositer_pid, ^exiter_pid]} = Core.check_in(state, depositer_pid, 1, :depositer)
    {:sync, 2} = Core.get_synced_height(state)

    {:ok, state} = Core.check_out(state, depositer_pid)
    :nosync = Core.get_synced_height(state)
    {:ok, state, [^depositer_pid, ^exiter_pid]} = Core.check_in(state, depositer_pid, 1, :depositer)
    {:sync, 2} = Core.get_synced_height(state)
  end

  test "returns services to sync up only for the last service checking in at a given height" do
    depositer_pid = :c.pid(0, 1, 0)
    exiter_pid = :c.pid(0, 2, 0)
    block_getter_pid = :c.pid(0, 3, 0)

    state = %Core{allowed_services: MapSet.new([:exiter, :depositer, :block_getter]), root_chain_height: 10}

    {:ok, state, []} = Core.check_in(state, exiter_pid, 1, :exiter)
    {:ok, state, []} = Core.check_in(state, depositer_pid, 1, :depositer)

    {:ok, _state, [^block_getter_pid, ^depositer_pid, ^exiter_pid]} =
      Core.check_in(state, block_getter_pid, 1, :block_getter)
  end

  @tag fixtures: [:initial_state]
  test "updates root chain height", %{initial_state: state} do
    depositer_pid = :c.pid(0, 1, 0)
    exiter_pid = :c.pid(0, 2, 0)

    {:ok, state, []} = Core.check_in(state, exiter_pid, 10, :exiter)
    {:ok, state, [^depositer_pid, ^exiter_pid]} = Core.check_in(state, depositer_pid, 10, :depositer)
    {:sync, 10} = Core.get_synced_height(state)

    {:ok, state} = Core.update_root_chain_height(state, 11)
    {:sync, 11} = Core.get_synced_height(state)
  end
end

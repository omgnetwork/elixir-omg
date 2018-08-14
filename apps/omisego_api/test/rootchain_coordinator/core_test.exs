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
defmodule OmiseGO.API.RootchainCoordinator.CoreTest do
  use ExUnitFixtures
  use ExUnit.Case, async: true

  alias OmiseGO.API.RootchainCoordinator.Core

  deffixture initial_state() do
    %Core{allowed_services: MapSet.new([:exiter, :depositer]), root_chain_height: 10}
  end

  @tag fixtures: [:initial_state]
  test "does not synchronize service that is not allowed", %{initial_state: state} do
    :service_not_allowed = Core.sync(state, :c.pid(0, 1, 0), 10, :unallowed_service)
  end

  @tag fixtures: [:initial_state]
  test "synchronizes services", %{initial_state: state} do
    depositer_pid = :c.pid(0, 1, 0)
    exiter_pid = :c.pid(0, 2, 0)

    {:ok, state} = Core.sync(state, exiter_pid, 1, :exiter)
    :no_sync = Core.get_rootchain_height(state)

    {:ok, state} = Core.sync(state, depositer_pid, 2, :depositer)
    {:sync, 2} = Core.get_rootchain_height(state)

    {:ok, state} = Core.sync(state, exiter_pid, 1, :exiter)
    {:sync, 2} = Core.get_rootchain_height(state)
    {:ok, state} = Core.sync(state, exiter_pid, 2, :exiter)
    {:sync, 3} = Core.get_rootchain_height(state)
  end

  @tag fixtures: [:initial_state]
  test "deregisters and registers a service", %{initial_state: state} do
    depositer_pid = :c.pid(0, 1, 0)
    exiter_pid = :c.pid(0, 2, 0)

    {:ok, state} = Core.sync(state, exiter_pid, 1, :exiter)
    {:ok, state} = Core.sync(state, depositer_pid, 1, :depositer)
    {:sync, 2} = Core.get_rootchain_height(state)

    {:ok, state} = Core.deregister_service(state, depositer_pid)
    :no_sync = Core.get_rootchain_height(state)
    {:ok, state} = Core.sync(state, depositer_pid, 1, :depositer)
    {:sync, 2} = Core.get_rootchain_height(state)
  end

  @tag fixtures: [:initial_state]
  test "updates rootchain height", %{initial_state: state} do
    depositer_pid = :c.pid(0, 1, 0)
    exiter_pid = :c.pid(0, 2, 0)

    {:ok, state} = Core.sync(state, exiter_pid, 10, :exiter)
    {:ok, state} = Core.sync(state, depositer_pid, 10, :depositer)
    {:sync, 10} = Core.get_rootchain_height(state)

    {:ok, state} = Core.update_rootchain_height(state, 11)
    {:sync, 11} = Core.get_rootchain_height(state)
  end
end

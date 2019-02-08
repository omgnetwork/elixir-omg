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

  import ExUnit.CaptureLog

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

    assert {:ok, state, []} = Core.check_in(state, exiter_pid, 1, :exiter)
    assert :nosync = Core.get_synced_info(state, depositor_pid)
    assert %{sync_height: 10} = Core.get_synced_info(state, exiter_pid)

    assert {:ok, state, [^depositor_pid, ^exiter_pid]} = Core.check_in(state, depositor_pid, 2, :depositor)
    assert %{sync_height: 2} = Core.get_synced_info(state, depositor_pid)
    assert %{sync_height: 10} = Core.get_synced_info(state, exiter_pid)

    assert {:ok, state, []} = Core.check_in(state, exiter_pid, 10, :exiter)
    assert %{sync_height: 3} = Core.get_synced_info(state, depositor_pid)
    assert %{sync_height: 10} = Core.get_synced_info(state, exiter_pid)
  end

  @tag fixtures: [:initial_state]
  test "deregisters and registers a service", %{initial_state: state} do
    depositor_pid = :c.pid(0, 1, 0)
    exiter_pid = :c.pid(0, 2, 0)

    assert {:ok, state, []} = Core.check_in(state, exiter_pid, 1, :exiter)
    assert {:ok, state, [^depositor_pid, ^exiter_pid]} = Core.check_in(state, depositor_pid, 1, :depositor)
    assert %{sync_height: 2} = Core.get_synced_info(state, depositor_pid)
    assert %{sync_height: 10} = Core.get_synced_info(state, exiter_pid)

    assert {:ok, state} = Core.check_out(state, depositor_pid)
    assert :nosync = Core.get_synced_info(state, depositor_pid)

    assert {:ok, state, [^depositor_pid, ^exiter_pid]} = Core.check_in(state, depositor_pid, 1, :depositor)
    assert %{sync_height: 2} = Core.get_synced_info(state, depositor_pid)
    assert %{sync_height: 10} = Core.get_synced_info(state, exiter_pid)
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

    assert {:ok, state, []} = Core.check_in(state, exiter_pid, 1, :exiter)
    assert {:ok, state, []} = Core.check_in(state, depositor_pid, 1, :depositor)

    assert {:ok, _state, [^block_getter_pid, ^depositor_pid, ^exiter_pid]} =
             Core.check_in(state, block_getter_pid, 1, :block_getter)
  end

  @tag fixtures: [:initial_state]
  test "updates root chain height", %{initial_state: state} do
    depositor_pid = :c.pid(0, 1, 0)
    exiter_pid = :c.pid(0, 2, 0)

    assert {:ok, state, []} = Core.check_in(state, exiter_pid, 10, :exiter)
    assert {:ok, state, [^depositor_pid, ^exiter_pid]} = Core.check_in(state, depositor_pid, 10, :depositor)
    assert %{sync_height: 10} = Core.get_synced_info(state, depositor_pid)
    assert %{sync_height: 10} = Core.get_synced_info(state, exiter_pid)

    assert {:ok, state} = Core.update_root_chain_height(state, 11)
    assert %{sync_height: 11} = Core.get_synced_info(state, depositor_pid)
    assert %{sync_height: 11} = Core.get_synced_info(state, exiter_pid)

    assert {:ok, state} = Core.update_root_chain_height(state, 14)
    assert %{sync_height: 11} = Core.get_synced_info(state, depositor_pid)
    assert %{sync_height: 14} = Core.get_synced_info(state, exiter_pid)
  end

  @tag fixtures: [:initial_state]
  test "root chain back off is ignored", %{initial_state: state} do
    depositor_pid = :c.pid(0, 1, 0)
    exiter_pid = :c.pid(0, 2, 0)

    assert {:ok, state, _} = Core.check_in(state, exiter_pid, 10, :exiter)
    assert {:ok, state, _} = Core.check_in(state, depositor_pid, 10, :depositor)
    assert %{sync_height: 10} = Core.get_synced_info(state, depositor_pid)
    assert %{sync_height: 10} = Core.get_synced_info(state, exiter_pid)

    assert {:ok, state} = Core.update_root_chain_height(state, 9)
    assert %{sync_height: 10} = Core.get_synced_info(state, depositor_pid)
    assert %{sync_height: 10} = Core.get_synced_info(state, exiter_pid)

    assert {:ok, state} = Core.update_root_chain_height(state, 11)
    assert %{sync_height: 11} = Core.get_synced_info(state, depositor_pid)
    assert %{sync_height: 11} = Core.get_synced_info(state, exiter_pid)
  end

  # TODO: testing via assert_raise is not elegant in our setup, rethink
  test "invalid synced height update, gives richer error information" do
    service_pid = :c.pid(0, 1, 0)

    {:ok, state, _} =
      Core.init(%{:some_service => %{sync_mode: :sync_with_coordinator}}, 11)
      |> Core.check_in(service_pid, 11, :some_service)

    logs_error =
      capture_log(fn ->
        assert_raise MatchError, fn -> Core.check_in(state, service_pid, 10, :some_service) end
      end)

    assert logs_error =~ "synced_height: 11"
    assert logs_error =~ "new_reported_sync_height: 10"
    assert logs_error =~ "some_service"
  end
end

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
defmodule OMG.RootChainCoordinator.CoreTest do
  use ExUnitFixtures
  use ExUnit.Case, async: true

  alias OMG.RootChainCoordinator.Core

  deffixture initial_state() do
    Core.init(%{:depositor => [], :exiter => [waits_for: :depositor]}, 10)
  end

  @tag fixtures: [:initial_state]
  test "does not synchronize service that is not allowed", %{initial_state: state} do
    {:error, :service_not_allowed} = Core.check_in(state, :c.pid(0, 1, 0), 10, :unallowed_service)
  end

  @tag fixtures: [:initial_state]
  test "synchronizes services", %{initial_state: state} do
    depositor_pid = :c.pid(0, 1, 0)
    exiter_pid = :c.pid(0, 2, 0)

    assert {:ok, state} = Core.check_in(state, exiter_pid, 1, :exiter)
    assert :nosync = Core.get_synced_info(state, depositor_pid)
    assert :nosync = Core.get_synced_info(state, exiter_pid)

    assert {:ok, state} = Core.check_in(state, depositor_pid, 2, :depositor)
    assert %{sync_height: 10} = Core.get_synced_info(state, depositor_pid)
    assert %{sync_height: 2} = Core.get_synced_info(state, exiter_pid)

    assert {:ok, state} = Core.check_in(state, exiter_pid, 2, :exiter)
    assert %{sync_height: 10} = Core.get_synced_info(state, depositor_pid)
    assert %{sync_height: 2} = Core.get_synced_info(state, exiter_pid)

    assert {:ok, state} = Core.check_in(state, depositor_pid, 3, :depositor)
    assert %{sync_height: 10} = Core.get_synced_info(state, depositor_pid)
    assert %{sync_height: 3} = Core.get_synced_info(state, exiter_pid)
  end

  @tag fixtures: [:initial_state]
  test "deregisters and registers a service", %{initial_state: state} do
    depositor_pid = :c.pid(0, 1, 0)
    exiter_pid = :c.pid(0, 2, 0)

    assert {:ok, state} = Core.check_in(state, exiter_pid, 1, :exiter)
    assert {:ok, state} = Core.check_in(state, depositor_pid, 1, :depositor)
    assert %{sync_height: 10} = Core.get_synced_info(state, depositor_pid)
    assert %{sync_height: 1} = Core.get_synced_info(state, exiter_pid)

    assert {:ok, state} = Core.check_out(state, depositor_pid)
    assert :nosync = Core.get_synced_info(state, depositor_pid)
    assert :nosync = Core.get_synced_info(state, exiter_pid)
    assert :nosync = Core.get_synced_info(state, :depositor)
    assert :nosync = Core.get_synced_info(state, :exiter)

    depositor_pid2 = :c.pid(0, 3, 0)
    assert {:ok, state} = Core.check_in(state, depositor_pid2, 2, :depositor)
    assert %{sync_height: 10} = Core.get_synced_info(state, depositor_pid2)
    assert %{sync_height: 2} = Core.get_synced_info(state, exiter_pid)
  end

  @tag fixtures: [:initial_state]
  test "updates root chain height", %{initial_state: state} do
    depositor_pid = :c.pid(0, 1, 0)
    exiter_pid = :c.pid(0, 2, 0)

    assert {:ok, state} = Core.check_in(state, exiter_pid, 10, :exiter)
    assert {:ok, state} = Core.check_in(state, depositor_pid, 10, :depositor)
    assert %{sync_height: 10} = Core.get_synced_info(state, depositor_pid)
    assert %{sync_height: 10} = Core.get_synced_info(state, exiter_pid)

    assert {:ok, state} = Core.update_root_chain_height(state, 11)
    assert %{sync_height: 11} = Core.get_synced_info(state, depositor_pid)
    assert %{sync_height: 10} = Core.get_synced_info(state, exiter_pid)

    assert {:ok, state} = Core.update_root_chain_height(state, 14)
    assert %{sync_height: 14} = Core.get_synced_info(state, depositor_pid)
    assert %{sync_height: 10} = Core.get_synced_info(state, exiter_pid)
  end

  @tag fixtures: [:initial_state]
  test "reports synced heights", %{initial_state: state} do
    exiter_pid = :c.pid(0, 2, 0)

    assert %{root_chain_height: 10} == Core.get_ethereum_heights(state)
    assert {:ok, state} = Core.check_in(state, exiter_pid, 10, :exiter)
    assert %{root_chain_height: 10, exiter: 10} == Core.get_ethereum_heights(state)
    assert {:ok, state} = Core.update_root_chain_height(state, 11)
    assert %{root_chain_height: 11, exiter: 10} == Core.get_ethereum_heights(state)
  end

  @tag fixtures: [:initial_state]
  test "prevents huge queries to Ethereum client", %{initial_state: state} do
    depositor_pid = :c.pid(0, 1, 0)
    exiter_pid = :c.pid(0, 2, 0)

    assert {:ok, state} = Core.check_in(state, exiter_pid, 10, :exiter)
    assert {:ok, state} = Core.check_in(state, depositor_pid, 10, :depositor)
    assert {:ok, state} = Core.update_root_chain_height(state, 11_000_000)
    assert %{sync_height: new_sync_height} = Core.get_synced_info(state, depositor_pid)
    assert new_sync_height < 100_000
  end

  @tag fixtures: [:initial_state]
  test "root chain back off is ignored", %{initial_state: state} do
    depositor_pid = :c.pid(0, 1, 0)
    exiter_pid = :c.pid(0, 2, 0)

    assert {:ok, state} = Core.check_in(state, exiter_pid, 10, :exiter)
    assert {:ok, state} = Core.check_in(state, depositor_pid, 10, :depositor)
    assert %{sync_height: 10} = Core.get_synced_info(state, depositor_pid)
    assert %{sync_height: 10} = Core.get_synced_info(state, exiter_pid)

    assert {:ok, state} = Core.update_root_chain_height(state, 9)
    assert %{sync_height: 10} = Core.get_synced_info(state, depositor_pid)
    assert %{sync_height: 10} = Core.get_synced_info(state, exiter_pid)

    assert {:ok, state} = Core.update_root_chain_height(state, 11)
    assert %{sync_height: 11} = Core.get_synced_info(state, depositor_pid)
    assert %{sync_height: 10} = Core.get_synced_info(state, exiter_pid)
  end

  @pid %{
    depositor: :c.pid(0, 1, 0),
    exiter: :c.pid(0, 2, 0),
    depositor_finality: :c.pid(0, 3, 0),
    exiter_finality: :c.pid(0, 4, 0),
    getter: :c.pid(0, 5, 0),
    finalizer: :c.pid(0, 6, 0)
  }

  deffixture bigger_state() do
    state =
      Core.init(
        %{
          :depositor => [],
          :exiter => [waits_for: :depositor],
          :depositor_finality => [finality_margin: 2],
          :exiter_finality => [waits_for: :depositor, finality_margin: 2],
          :getter => [waits_for: [depositor_finality: :no_margin]],
          :finalizer => [waits_for: [:getter, :depositor]]
        },
        10
      )

    {:ok, state} = Core.check_in(state, @pid[:depositor], 1, :depositor)
    {:ok, state} = Core.check_in(state, @pid[:exiter], 1, :exiter)
    {:ok, state} = Core.check_in(state, @pid[:depositor_finality], 1, :depositor_finality)
    {:ok, state} = Core.check_in(state, @pid[:exiter_finality], 1, :exiter_finality)
    {:ok, state} = Core.check_in(state, @pid[:getter], 1, :getter)
    {:ok, state} = Core.check_in(state, @pid[:finalizer], 1, :finalizer)
    state
  end

  @tag fixtures: [:bigger_state]
  test "waiting service will wait and progress accordingly",
       %{bigger_state: state} do
    assert %{sync_height: 1} = Core.get_synced_info(state, @pid[:exiter])
    {:ok, state} = Core.check_in(state, @pid[:depositor], 2, :depositor)
    assert %{sync_height: 2} = Core.get_synced_info(state, @pid[:exiter])
    {:ok, state} = Core.check_in(state, @pid[:depositor], 5, :depositor)
    assert %{sync_height: 5} = Core.get_synced_info(state, @pid[:exiter])
  end

  @tag fixtures: [:bigger_state]
  test "waiting for multiple",
       %{bigger_state: state} do
    assert %{sync_height: 1} = Core.get_synced_info(state, @pid[:finalizer])
    {:ok, state} = Core.check_in(state, @pid[:depositor], 2, :depositor)
    assert %{sync_height: 1} = Core.get_synced_info(state, @pid[:finalizer])
    {:ok, state} = Core.check_in(state, @pid[:getter], 2, :getter)
    assert %{sync_height: 2} = Core.get_synced_info(state, @pid[:finalizer])
    {:ok, state} = Core.check_in(state, @pid[:depositor], 5, :depositor)
    {:ok, state} = Core.check_in(state, @pid[:getter], 5, :getter)
    assert %{sync_height: 5} = Core.get_synced_info(state, @pid[:finalizer])
  end

  @tag fixtures: [:bigger_state]
  test "waiting when margin of the awaited process should be skipped ahead",
       %{bigger_state: state} do
    assert %{sync_height: 3} = Core.get_synced_info(state, @pid[:getter])
    {:ok, state} = Core.check_in(state, @pid[:depositor_finality], 5, :depositor_finality)
    assert %{sync_height: 7} = Core.get_synced_info(state, @pid[:getter])
    {:ok, state} = Core.check_in(state, @pid[:depositor_finality], 8, :depositor_finality)
    assert %{sync_height: 10} = Core.get_synced_info(state, @pid[:getter])

    assert {:ok, state} = Core.update_root_chain_height(state, 11)

    assert %{sync_height: 10} = Core.get_synced_info(state, @pid[:getter])
    {:ok, state} = Core.check_in(state, @pid[:depositor_finality], 9, :depositor_finality)
    assert %{sync_height: 11} = Core.get_synced_info(state, @pid[:getter])

    # sanity check - will not accidently spill over root chain height (but depositor wouldn't likely check in at 11)
    {:ok, state} = Core.check_in(state, @pid[:depositor_finality], 11, :depositor_finality)
    assert %{sync_height: 11} = Core.get_synced_info(state, @pid[:getter])
  end

  @tag fixtures: [:bigger_state]
  test "waiting only for the finality margin",
       %{bigger_state: state} do
    assert %{sync_height: 8} = Core.get_synced_info(state, @pid[:depositor_finality])
    {:ok, state} = Core.check_in(state, @pid[:depositor_finality], 5, :depositor_finality)
    assert %{sync_height: 8} = Core.get_synced_info(state, @pid[:depositor_finality])
    assert {:ok, state} = Core.update_root_chain_height(state, 11)
    assert %{sync_height: 9} = Core.get_synced_info(state, @pid[:depositor_finality])
  end

  @tag fixtures: [:bigger_state]
  test "waiting only for the finality margin and some service",
       %{bigger_state: state} do
    assert %{sync_height: 1} = Core.get_synced_info(state, @pid[:exiter_finality])
    {:ok, state} = Core.check_in(state, @pid[:depositor], 5, :depositor)
    assert %{sync_height: 5} = Core.get_synced_info(state, @pid[:exiter_finality])
    assert {:ok, state} = Core.update_root_chain_height(state, 11)
    assert %{sync_height: 5} = Core.get_synced_info(state, @pid[:exiter_finality])
    {:ok, state} = Core.check_in(state, @pid[:depositor], 9, :depositor)
    assert %{sync_height: 9} = Core.get_synced_info(state, @pid[:exiter_finality])

    # is reorg safe - root chain height going backwards is ignored
    assert {:ok, state} = Core.update_root_chain_height(state, 10)
    assert %{sync_height: 9} = Core.get_synced_info(state, @pid[:exiter_finality])
  end

  test "behaves well close to zero",
       %{} do
    state = Core.init(%{:depositor => [finality_margin: 2], :exiter => [waits_for: :depositor, finality_margin: 2]}, 0)

    {:ok, state} = Core.check_in(state, @pid[:depositor], 0, :depositor)
    {:ok, state} = Core.check_in(state, @pid[:exiter], 0, :exiter)
    assert %{sync_height: 0} = Core.get_synced_info(state, @pid[:depositor])
    assert %{sync_height: 0} = Core.get_synced_info(state, @pid[:exiter])
    assert {:ok, state} = Core.update_root_chain_height(state, 1)
    assert %{sync_height: 0} = Core.get_synced_info(state, @pid[:depositor])
    assert %{sync_height: 0} = Core.get_synced_info(state, @pid[:exiter])
    assert {:ok, state} = Core.update_root_chain_height(state, 3)
    assert %{sync_height: 1} = Core.get_synced_info(state, @pid[:depositor])
    assert %{sync_height: 0} = Core.get_synced_info(state, @pid[:exiter])
    {:ok, state} = Core.check_in(state, @pid[:depositor], 1, :depositor)
    assert %{sync_height: 1} = Core.get_synced_info(state, @pid[:exiter])
  end

  @tag fixtures: [:bigger_state]
  test "root chain heights reported observe the finality margin, if present",
       %{bigger_state: state} do
    assert %{root_chain_height: 10} = Core.get_synced_info(state, @pid[:depositor])
    assert %{root_chain_height: 8} = Core.get_synced_info(state, @pid[:depositor_finality])
    assert %{root_chain_height: 10} = Core.get_synced_info(state, @pid[:exiter])
    assert %{root_chain_height: 8} = Core.get_synced_info(state, @pid[:exiter_finality])
    assert %{root_chain_height: 10} = Core.get_synced_info(state, @pid[:getter])
  end
end

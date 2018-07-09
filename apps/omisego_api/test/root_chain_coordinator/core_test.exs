defmodule OmiseGO.API.RootChainCoordinator.CoreTest do
  use ExUnitFixtures
  use ExUnit.Case, async: true

  alias OmiseGO.API.RootChainCoordinator.Core

  deffixture initial_state() do
    %Core{allowed_services: MapSet.new([:exiter, :depositer]), root_chain_height: 10}
  end

  @tag fixtures: [:initial_state]
  test "does not synchronize service that is not allowed", %{initial_state: state} do
    :service_not_allowed = Core.sync(state, {self(), :tag}, 10, :unallowed_service)
  end

  @tag fixtures: [:initial_state]
  test "synchronizes services", %{initial_state: state} do
    depositer_handle = {:c.pid(0, 1, 0), :depositer_handle}
    exiter_handle = {:c.pid(0, 2, 0), :exiter_handle}
    depositer_height = 9
    {:no_sync, state} = Core.sync(state, depositer_handle, depositer_height, :depositer)

    exiter_height = 8
    {:sync, [^exiter_handle], ^depositer_height, state} = Core.sync(state, exiter_handle, exiter_height, :exiter)

    exiter_height = 9
    next_sync_height = 10

    {:sync, [^depositer_handle, ^exiter_handle], ^next_sync_height, state} =
      Core.sync(state, exiter_handle, exiter_height, :exiter)

    depositer_height = 10
    {:no_sync, state} = Core.sync(state, depositer_handle, depositer_height, :depositer)
    exiter_height = 10
    {:no_sync, _} = Core.sync(state, exiter_handle, exiter_height, :exiter)
  end

  @tag fixtures: [:initial_state]
  test "deregisters a service", %{initial_state: state} do
    depositor_pid = :c.pid(0, 1, 0)
    depositer_handle = {depositor_pid, :depositer_handle}
    exiter_pid = :c.pid(0, 2, 0)
    exiter_handle = {exiter_pid, :exiter_handle}
    height = 8
    next_sync_height = 9
    {:no_sync, state} = Core.sync(state, depositer_handle, height, :depositer)

    {:sync, [^depositer_handle, ^exiter_handle], ^next_sync_height, state} =
      Core.sync(state, exiter_handle, height, :exiter)

    state = Core.deregister_service(state, exiter_pid)

    {:no_sync, state} = Core.sync(state, depositer_handle, next_sync_height, :depositer)
    {:sync, [^depositer_handle, ^exiter_handle], 10, _} = Core.sync(state, exiter_handle, next_sync_height, :exiter)
  end

  @tag fixtures: [:initial_state]
  test "updates root height", %{initial_state: state} do
    depositer_handle = {:c.pid(0, 1, 0), :depositer_handle}
    exiter_handle = {:c.pid(0, 2, 0), :exiter_handle}
    height = 9
    next_sync_height = 10
    {:no_sync, state} = Core.sync(state, exiter_handle, height, :exiter)

    {:sync, [^depositer_handle, ^exiter_handle], ^next_sync_height, state} =
      Core.sync(state, depositer_handle, height, :depositer)

    height = next_sync_height
    {:no_sync, state} = Core.sync(state, exiter_handle, height, :exiter)
    {:no_sync, _} = Core.sync(state, depositer_handle, height, :depositer)
  end
end

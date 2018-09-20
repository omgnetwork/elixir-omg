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
defmodule OMG.API.RootChainCoordinator.Core do
  @moduledoc """
  Synchronizes services on root chain height.
  Each synchronized service must have a unique name.
  Service reports its height by calling 'check_in'.
  After all the services are checked in, coordinator returns currently synchronized height.
  In case a service fails, it is checked out and coordinator does not resume until the missing service checks_in again.
  After all the services checked in with the same height, coordinator returns the next root chain height when calling `check_in`.
  Coordinator periodically updates root chain height.
  """

  alias OMG.API.RootChainCoordinator.Service

  @empty MapSet.new()

  defstruct allowed_services: @empty, root_chain_height: 0, services: %{}

  @type t() :: %__MODULE__{
          allowed_services: MapSet.t(),
          root_chain_height: non_neg_integer(),
          services: map()
        }

  @doc """
  Initializes core.
  `allowed_services` - set of names of services that are being synchronized
  `root_chain_height` - current root chain height
  """
  @spec init(MapSet.t(), non_neg_integer()) :: t()
  def init(allowed_services, root_chain_height) do
    %__MODULE__{allowed_services: allowed_services, root_chain_height: root_chain_height}
  end

  @doc """
  Updates Ethereum height on which a service is synchronized.
  Returns list of pids of services to synchronize on next Ethereum height.
  List is not empty only when service that checks in is the last one synchronizing on a given height.
  """
  @spec check_in(t(), pid(), pos_integer(), atom()) :: {:ok, t(), list(pid())} | :service_not_allowed
  def check_in(state, pid, service_height, service_name) do
    if allowed?(state.allowed_services, service_name) do
      previous_synced_height =
        case get_synced_height(state) do
          :nosync ->
            0

          {:sync, synced_height} ->
            synced_height
        end

      {:ok, state} = update_service_synced_height(state, pid, service_height, service_name)
      services_to_sync = get_services_to_sync(state, previous_synced_height)

      {:ok, state, services_to_sync}
    else
      :service_not_allowed
    end
  end

  defp allowed?(allowed_services, service_name), do: MapSet.member?(allowed_services, service_name)

  defp update_service_synced_height(state, pid, service_current_sync_height, service_name) do
    service = %Service{synced_height: service_current_sync_height, pid: pid}

    if valid_sync_height_update?(state, service, service_current_sync_height, service_name) do
      services = Map.put(state.services, service_name, service)
      state = %{state | services: services}
      {:ok, state}
    else
      :invalid_synced_height_update
    end
  end

  defp valid_sync_height_update?(state, synced_service, service_current_sync_height, service_name) do
    service = Map.get(state.services, service_name, synced_service)
    service.synced_height <= service_current_sync_height and state.root_chain_height >= service_current_sync_height
  end

  defp get_services_to_sync(state, previous_synced_height) do
    case get_synced_height(state) do
      :nosync ->
        []

      {:sync, synced_height} when synced_height > previous_synced_height ->
        state.services
        |> Map.values()
        |> Enum.filter(fn service -> service.synced_height <= synced_height end)
        |> Enum.map(& &1.pid)

      {:sync, _} ->
        []
    end
  end

  @doc """
  Gets synchronized height
  """
  @spec get_synced_height(t()) :: {:sync, non_neg_integer()} | :nosync
  def get_synced_height(state) do
    if all_services_checked_in?(state) do
      # do not allow syncing to Ethereum blocks higher than block last seen by synchronizer
      next_sync_height = min(sync_height(state.services) + 1, state.root_chain_height)
      {:sync, next_sync_height}
    else
      :nosync
    end
  end

  defp all_services_checked_in?(state) do
    registered =
      state.services
      |> Map.keys()
      |> MapSet.new()

    state.allowed_services == registered
  end

  defp sync_height(services) do
    services
    |> Map.values()
    |> Enum.map(& &1.synced_height)
    |> Enum.min()
  end

  @doc """
  Removes service from services being synchronized
  """
  @spec check_out(t(), pid()) :: {:ok, t()}
  def check_out(state, pid) do
    {service_name, _} =
      state.services
      |> Enum.find(fn {_, service} -> service.pid == pid end)

    services = Map.delete(state.services, service_name)
    state = %{state | services: services}
    {:ok, state}
  end

  @doc """
  Sets root chain height
  """
  @spec update_root_chain_height(t(), pos_integer()) :: {:ok, t()}
  def update_root_chain_height(state, root_chain_height) do
    {:ok, %{state | root_chain_height: root_chain_height}}
  end
end

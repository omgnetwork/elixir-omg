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
defmodule OmiseGO.API.RootchainCoordinator.Core do
  @moduledoc """
  Synchronizes services on rootchain height.
  Each synchronized service must have a unique name.
  Service reports its height by calling 'check_in'.
  After all the services are checked in, coordinator returns currently synchronized height.
  In case a service fails, it is checked out and coordinator does not resume until the missing service checks_in again.
  After all the services checked in with the same height, coordinator returns the next rootchain height when calling `check_in`.
  Coordinator periodically updates rootchain height.
  """

  alias OmiseGO.API.RootchainCoordinator.Service

  @empty MapSet.new()

  defstruct allowed_services: @empty, rootchain_height: 0, services: %{}

  @type t() :: %__MODULE__{
          allowed_services: MapSet.t(),
          rootchain_height: non_neg_integer(),
          services: map()
        }

  @doc """
  Initializes core.
  `allowed_services` - set of names of services that are being synchronized
  `rootchain_height` - current rootchain height
  """
  @spec init(MapSet.t(), non_neg_integer()) :: t()
  def init(allowed_services, rootchain_height) do
    %__MODULE__{allowed_services: allowed_services, rootchain_height: rootchain_height}
  end

  @doc """
  Updates Ethereum height on which a service is synchronized.
  """
  @spec check_in(t(), pid(), pos_integer(), atom()) :: {:ok, t()} | :service_not_allowed
  def check_in(state, pid, service_height, service_name) do
    if allowed?(state.allowed_services, service_name) do
      update_service_synced_height(state, pid, service_height, service_name)
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
    service.synced_height <= service_current_sync_height and state.rootchain_height >= service_current_sync_height
  end

  @doc """
  Gets synchronized height
  """
  @spec get_rootchain_height(t()) :: {:sync, non_neg_integer()} | :nosync
  def get_rootchain_height(state) do
    if all_services_checked_in?(state) do
      # do not allow syncing to Ethereum blocks higher than block last seen by synchronizer
      next_sync_height = min(sync_height(state.services) + 1, state.rootchain_height)
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
  Sets rootchain height
  """
  @spec update_rootchain_height(t(), pos_integer()) :: {:ok, t()}
  def update_rootchain_height(state, rootchain_height) do
    {:ok, %{state | rootchain_height: rootchain_height}}
  end
end

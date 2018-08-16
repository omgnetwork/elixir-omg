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
  Functional core of root chain coordinator.
  """

  alias OmiseGO.API.RootchainCoordinator.Service

  @empty MapSet.new()

  defstruct allowed_services: @empty, rootchain_height: 0, services: %{}

  @type t() :: %__MODULE__{
          allowed_services: MapSet.t(),
          rootchain_height: non_neg_integer(),
          services: map()
        }

  def init(allowed_services, rootchain_height) do
    %__MODULE__{allowed_services: allowed_services, rootchain_height: rootchain_height}
  end

  @doc """
  Updates Ethereum height on which a service is synchronized.
  """
  @spec sync(t(), pid(), pos_integer(), atom()) :: {:ok, t()} | :service_not_allowed
  def sync(state, pid, service_height, service_name) do
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
    if all_services_registered?(state) do
      # do not allow syncing to Ethereum blocks higher than block last seen by synchronizer
      next_sync_height = min(sync_height(state.services) + 1, state.rootchain_height)
      {:sync, next_sync_height}
    else
      :nosync
    end
  end

  defp all_services_registered?(state) do
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
  @spec remove_service(t(), pid()) :: {:ok, t()}
  def remove_service(state, pid) do
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

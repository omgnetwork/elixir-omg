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
  alias OMG.API.RootChainCoordinator.SyncData

  use OMG.API.LoggerExt

  defstruct configs_services: %{}, root_chain_height: 0, services: %{}

  @type configs_services :: %{required(atom()) => %{sync_mode: :sync_with_root_chain | :sync_with_coordinator}}

  @type t() :: %__MODULE__{
          configs_services: configs_services,
          root_chain_height: non_neg_integer(),
          services: map()
        }

  @doc """
  Initializes core.
  `configs_services` - configs of services that are being synchronized
  `root_chain_height` - current root chain height
  """
  @spec init(map(), non_neg_integer()) :: t()
  def init(configs_services, root_chain_height) do
    %__MODULE__{configs_services: configs_services, root_chain_height: root_chain_height}
  end

  @doc """
  Updates Ethereum height on which a service is synchronized.
  Returns list of pids of services to synchronize on next Ethereum height.
  List is not empty only when service that checks in is the last one synchronizing on a given height.
  """
  @spec check_in(t(), pid(), pos_integer(), atom()) :: {:ok, t(), list(pid())} | :service_not_allowed
  def check_in(state, pid, service_height, service_name) when is_integer(service_height) do
    if allowed?(state.configs_services, service_name) do
      previous_synced_height =
        case get_synced_info(state, service_name) do
          :nosync ->
            0

          %SyncData{sync_height: synced_height} ->
            synced_height
        end

      {:ok, state} = update_service_synced_height(state, pid, service_height, service_name)
      services_to_sync = get_services_to_sync(state, service_name, previous_synced_height)

      {:ok, state, services_to_sync}
    else
      :service_not_allowed
    end
  end

  defp allowed?(configs_services, service_name), do: Map.has_key?(configs_services, service_name)

  defp update_service_synced_height(
         %__MODULE__{services: services, root_chain_height: root_chain_height} = state,
         pid,
         new_reported_sync_height,
         service_name
       ) do
    new_service_state = %Service{synced_height: new_reported_sync_height, pid: pid}
    current_service_state = Map.get(services, service_name, new_service_state)

    if valid_sync_height_update?(current_service_state, root_chain_height, new_reported_sync_height) do
      {:ok, %{state | services: Map.put(services, service_name, new_service_state)}}
    else
      report_data = %{
        current: current_service_state,
        service_name: service_name,
        root_chain_height: root_chain_height,
        new_reported_sync_height: new_reported_sync_height
      }

      _ = Logger.error("Invalid synced height update #{inspect(report_data, pretty: true)}")
      {:ok, state}
    end
  end

  defp valid_sync_height_update?(
         %Service{synced_height: current_synced_height},
         root_chain_height,
         new_reported_sync_height
       ) do
    current_synced_height <= new_reported_sync_height and new_reported_sync_height <= root_chain_height
  end

  defp get_services_to_sync(state, service_name, previous_synced_height) do
    case get_synced_info(state, service_name) do
      :nosync ->
        []

      %SyncData{sync_height: synced_height} when synced_height > previous_synced_height ->
        state.services
        |> Map.values()
        |> Enum.filter(fn service -> service.synced_height <= synced_height end)
        |> Enum.map(& &1.pid)

      _ ->
        []
    end
  end

  @doc """
  Gets synchronized info
  """
  @spec get_synced_info(t(), atom() | pid()) :: SyncData.t() | :nosync
  def get_synced_info(state, pid) when is_pid(pid) do
    service = Enum.find(state.services, fn service -> match?({_, %Service{pid: ^pid}}, service) end)

    case service do
      {service_name, _} -> get_synced_info(state, service_name)
      nil -> :nosync
    end
  end

  def get_synced_info(state, service_name) when is_atom(service_name) do
    sync_mode =
      state.configs_services
      |> Map.get(service_name)
      |> Map.get(:sync_mode, :sync_with_coordinator)

    get_synced_info_by_mode(state, sync_mode)
  end

  defp get_synced_info_by_mode(
         %__MODULE__{services: services, root_chain_height: root_chain_height} = state,
         :sync_with_coordinator
       ) do
    if all_services_checked_in?(state) do
      # do not allow syncing to Ethereum blocks higher than block last seen by synchronizer
      next_sync_height = min(sync_height(services) + 1, root_chain_height)
      %SyncData{sync_height: next_sync_height, root_chain_height: root_chain_height}
    else
      :nosync
    end
  end

  defp get_synced_info_by_mode(%__MODULE__{root_chain_height: root_chain_height}, :sync_with_root_chain) do
    %SyncData{sync_height: root_chain_height, root_chain_height: root_chain_height}
  end

  defp all_services_checked_in?(%__MODULE__{configs_services: configs_services, services: services}) do
    sort = fn map -> map |> Map.keys() |> Enum.sort() end
    sort.(configs_services) == sort.(services)
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
  def check_out(%__MODULE__{} = state, pid) do
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
  def update_root_chain_height(%__MODULE__{} = state, root_chain_height) when is_integer(root_chain_height) do
    {:ok, %{state | root_chain_height: root_chain_height}}
  end
end

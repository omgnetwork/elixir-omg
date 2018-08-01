defmodule OmiseGO.API.RootChainCoordinator.Core do
  @moduledoc """
  Functional core of root chain coordinator.
  """

  alias OmiseGO.API.RootChainCoordinator.Service

  @empty MapSet.new()

  defstruct allowed_services: @empty, root_chain_height: 0, services: %{}

  @type t() :: %__MODULE__{
          allowed_services: MapSet.t(),
          root_chain_height: non_neg_integer(),
          services: map()
        }

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
    synced_service = %Service{synced_height: service_current_sync_height, pid: pid}

    if valid_sync_height_update?(state, synced_service, service_current_sync_height, service_name) do
      services = Map.put(state.services, service_name, synced_service)
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

  @spec get_rootchain_height(t()) :: {:sync, non_neg_integer()} | :no_sync
  def get_rootchain_height(state) do
    if all_services_registered?(state) do
      # do not allow syncing to Ethereum blocks higher than block last seen by synchronizer
      next_sync_height = min(sync_height(state.services) + 1, state.root_chain_height)
      {:sync, next_sync_height}
    else
      :no_sync
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
  Removes service from services participating in synchronization.
  """
  @spec deregister_service(t(), pid()) :: t()
  def deregister_service(state, pid) do
    {service_name, _} =
      state.services
      |> Map.to_list()
      |> Enum.find(fn {_, service} -> service.pid == pid end)

    services = Map.delete(state.services, service_name)
    state = %{state | services: services}
    {:ok, state}
  end

  @spec update_rootchain_height(t(), pos_integer()) :: t()
  def update_rootchain_height(state, rootchain_height) do
    {:ok, %{state | root_chain_height: rootchain_height}}
  end
end

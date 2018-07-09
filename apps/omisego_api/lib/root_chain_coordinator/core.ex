defmodule OmiseGO.API.RootChainCoordinator.Core do
  @moduledoc """
  Functional core of root chain coordinator.
  """

  alias OmiseGO.API.RootChainCoordinator.Service

  @empty MapSet.new()

  defstruct allowed_services: @empty, root_chain_height: 0, services: %{}, services_waiting_for_sync: @empty

  @type t() :: %__MODULE__{
          allowed_services: MapSet.t(),
          root_chain_height: non_neg_integer(),
          services: map(),
          services_waiting_for_sync: MapSet.t()
        }

  @doc """
  Updates Ethereum height on which a service is synchronized.

  Returns tuple of: services to be allowed to synchronize to next Ethereum height,
  next Ethereum block height, state.
  """
  @spec sync(t(), {pid(), atom()}, pos_integer(), atom()) ::
          {:sync, list(), pos_integer(), t()} | {:no_sync, t()} | :service_not_allowed
  def sync(state, from, service_height, service_name) do
    if allowed?(state.allowed_services, service_name) do
      {:ok, state} = update_service_synced_height(state, from, service_height, service_name)
      state = add_service_to_services_waiting_for_sync(state, service_name)
      get_syncs(state)
    else
      :service_not_allowed
    end
  end

  defp allowed?(allowed_services, service_name), do: MapSet.member?(allowed_services, service_name)

  defp update_service_synced_height(state, {pid, _} = from, service_current_sync_height, service_name) do
    synced_service = %Service{otp_handle: from, synced_height: service_current_sync_height, pid: pid}

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

  defp add_service_to_services_waiting_for_sync(state, service_name) do
    services_waiting_for_sync =
      state.services_waiting_for_sync
      |> MapSet.put(service_name)

    %{state | services_waiting_for_sync: services_waiting_for_sync}
  end

  defp get_syncs(state) do
    if all_services_registered?(state) do
      # do not allow syncing to Ethereum blocks higher than block last seen by synchronizer
      next_sync_height = min(sync_height(state.services) + 1, state.root_chain_height)

      {services_syncing_to_next_height, state} = get_services_waiting_to_sync(state, next_sync_height)

      if MapSet.size(services_syncing_to_next_height) > 0 do
        handles_to_services_waiting_to_sync = get_otp_handles(state, services_syncing_to_next_height)
        {:sync, handles_to_services_waiting_to_sync, next_sync_height, state}
      else
        {:no_sync, state}
      end
    else
      {:no_sync, state}
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

  defp get_services_waiting_to_sync(state, next_sync_height) do
    services_synced_lower_than_next_sync_height =
      state.services
      |> Map.to_list()
      |> Enum.filter(fn {_, service} -> service.synced_height < next_sync_height end)
      |> Enum.map(fn {service_name, _} -> service_name end)
      |> MapSet.new()

    waiting_services_than_can_be_synced =
      MapSet.intersection(state.services_waiting_for_sync, services_synced_lower_than_next_sync_height)

    waiting_services = MapSet.difference(state.services_waiting_for_sync, waiting_services_than_can_be_synced)
    state = %{state | services_waiting_for_sync: waiting_services}
    {waiting_services_than_can_be_synced, state}
  end

  defp get_otp_handles(state, services) do
    state.services
    |> Map.to_list()
    |> Enum.filter(fn {service_name, _} -> MapSet.member?(services, service_name) end)
    |> Enum.map(fn {_, service} -> service.otp_handle end)
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
    %{state | services: services}
  end

  @doc """
  Updates root chain height.
  Returns synchonization to happen after state changes its Ethereum height.
  """
  @spec get_synchronizations_for_updated_root_chain_height(t(), pos_integer()) ::
          {:sync, list(), pos_integer(), t()} | {:no_sync, t()}
  def get_synchronizations_for_updated_root_chain_height(state, root_chain_height) do
    state = %{state | root_chain_height: root_chain_height}
    get_syncs(state)
  end
end

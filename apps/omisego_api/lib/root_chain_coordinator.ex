defmodule OmiseGO.API.RootChainCoordinator do
  @moduledoc """
  Synchronizes services on root chain height.
  """

  alias OmiseGO.API.RootChainCoordinator.Core
  alias OmiseGO.Eth

  def start_link(allowed_services) do
    GenServer.start_link(__MODULE__, {:ok, allowed_services}, name: __MODULE__)
  end

  @doc """
  Notifies that calling service with name `service_name` is synced up to height `synced_height`.
  `synced_height` is the height that the service is synced when calling this function.
  """
  def synced(synced_height, service_name) do
    GenServer.call(__MODULE__, {:service_synced, synced_height, service_name}, :infinity)
  end

  use GenServer

  def init({:ok, allowed_services}) do
    {:ok, root_chain_height} = Eth.get_ethereum_height()
    schedule_get_ethereum_height()
    state = %Core{allowed_services: allowed_services, root_chain_height: root_chain_height}
    {:ok, state}
  end

  def handle_call({:service_synced, synced_height, service_name}, from, state) do
    case Core.sync(state, from, synced_height, service_name) do
      {:sync, services_waiting_for_next_height, next_height, state} ->
        sync_services(services_waiting_for_next_height, next_height)
        {:noreply, state}

      {:no_sync, state} ->
        {:noreply, state}
    end
  end

  defp sync_services(services, next_height) do
    for service <- services do
      GenServer.reply(service, {:ok, next_height})
    end
  end

  def handle_info(:get_ethereum_height, state) do
    {:ok, root_chain_height} = Eth.get_ethereum_height()
    schedule_get_ethereum_height()

    case Core.get_synchronizations_for_updated_root_chain_height(state, root_chain_height) do
      {:sync, services_waiting_for_next_height, next_height, state} ->
        sync_services(services_waiting_for_next_height, next_height)
        {:noreply, state}

      {:no_sync, state} ->
        {:noreply, state}
    end
  end

  def handle_info({:DOWN, _ref, :process, pid, _}, state) do
    state = Core.deregister_service(state, pid)
    {:noreply, state}
  end

  defp schedule_get_ethereum_height do
    Process.send_after(self(), :get_ethereum_height, 1000)
  end
end

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
defmodule OMG.API.RootChainCoordinator do
  @moduledoc """
  Synchronizes services on root chain height.
  """

  alias OMG.API.RootChainCoordinator.Core
  alias OMG.Eth

  use OMG.API.LoggerExt

  @spec start_link(Core.configs_services()) :: GenServer.on_start()
  def start_link(configs_services) do
    GenServer.start_link(__MODULE__, configs_services, name: __MODULE__)
  end

  @doc """
  Notifies that calling service with name `service_name` is synced up to height `synced_height`.
  `synced_height` is the height that the service is synced when calling this function.
  """
  @spec check_in(non_neg_integer(), atom()) :: :ok
  def check_in(synced_height, service_name) do
    GenServer.call(__MODULE__, {:check_in, synced_height, service_name})
  end

  @doc """
  Gets Ethereum height that services can synchronize up to.
  """
  @spec get_height() :: {:sync, non_neg_integer()} | :nosync
  def get_height do
    GenServer.call(__MODULE__, :get_synced_height)
  end

  use GenServer

  def init(configs_services) do
    {:ok, rootchain_height} = Eth.get_ethereum_height()

    height_sync_interval = Application.fetch_env!(:omg_api, :ethereum_status_check_interval_ms)
    {:ok, _} = schedule_get_ethereum_height(height_sync_interval)
    state = Core.init(configs_services, rootchain_height)

    configs_services
    |> Map.keys()
    |> request_sync()

    {:ok, state}
  end

  def handle_call({:check_in, synced_height, service_name}, {pid, _}, state) do
    _ = Logger.debug(fn -> "#{inspect(service_name)} checks in on height #{inspect(synced_height)}" end)
    {:ok, state, services_to_sync} = Core.check_in(state, pid, synced_height, service_name)
    _ = length(services_to_sync) > 0 and Logger.debug(fn -> "Services to sync: #{inspect(services_to_sync)}" end)
    request_sync(services_to_sync)
    {:reply, :ok, state, 60_000}
  end

  def handle_call(:get_synced_height, {pid, _}, state) do
    {:reply, Core.get_synced_height(state, pid), state}
  end

  def handle_info(:update_root_chain_height, state) do
    {:ok, root_chain_height} = Eth.get_ethereum_height()
    {:ok, state} = Core.update_root_chain_height(state, root_chain_height)
    {:noreply, state}
  end

  def handle_info({:DOWN, _ref, :process, pid, _}, state) do
    {:ok, state} = Core.check_out(state, pid)
    {:noreply, state}
  end

  def handle_info(:timeout, state) do
    _ = Logger.warn(fn -> "No new activity for 60 seconds. Are we dead?" end)
    {:noreply, state}
  end

  defp schedule_get_ethereum_height(interval) do
    :timer.send_interval(interval, self(), :update_root_chain_height)
  end

  defp request_sync(services) do
    Enum.each(services, fn service -> safe_send(service, :sync) end)
  end

  defp safe_send(registered_name_or_pid, msg) do
    try do
      send(registered_name_or_pid, msg)
    rescue
      ArgumentError ->
        msg
    end
  end
end

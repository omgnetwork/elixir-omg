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
defmodule OmiseGO.API.RootchainCoordinator do
  @moduledoc """
  Synchronizes services on root chain height.
  """

  alias OmiseGO.API.RootchainCoordinator.Core
  alias OmiseGO.Eth

  def start_link(allowed_services) do
    GenServer.start_link(__MODULE__, allowed_services, name: __MODULE__)
  end

  @doc """
  Notifies that calling service with name `service_name` is synced up to height `synced_height`.
  `synced_height` is the height that the service is synced when calling this function.
  """
  @spec set_service_height(non_neg_integer(), atom()) :: :ok
  def set_service_height(synced_height, service_name) do
    GenServer.call(__MODULE__, {:set_service_height, synced_height, service_name}, :infinity)
  end

  @doc """
  Gets Ethereum height that services can synchronize up to.
  """
  @spec get_height() :: {:sync, non_neg_integer()} | :nosync
  def get_height do
    GenServer.call(__MODULE__, :get_rootchain_height, :infinity)
  end

  use GenServer

  def init(allowed_services) do
    {:ok, rootchain_height} = Eth.get_ethereum_height()
    {:ok, _} = schedule_get_ethereum_height()
    state = Core.init(MapSet.new(allowed_services), rootchain_height)
    {:ok, state}
  end

  def handle_call({:set_service_height, synced_height, service_name}, {pid, _}, state) do
    {:ok, state} = Core.sync(state, pid, synced_height, service_name)
    {:reply, :ok, state}
  end

  def handle_call(:get_rootchain_height, _from, state) do
    {:reply, Core.get_rootchain_height(state), state}
  end

  def handle_info(:update_rootchain_height, state) do
    {:ok, rootchain_height} = Eth.get_ethereum_height()
    {:ok, state} = Core.update_rootchain_height(state, rootchain_height)
    {:noreply, state}
  end

  def handle_info({:DOWN, _ref, :process, pid, _}, state) do
    {:ok, state} = Core.remove_service(state, pid)
    {:noreply, state}
  end

  defp schedule_get_ethereum_height(interval \\ 200) do
    :timer.send_interval(interval, self(), :update_rootchain_height)
  end
end

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
defmodule OMG.RootChainCoordinator do
  @moduledoc """
  Synchronizes services on root chain height, see `OMG.RootChainCoordinator.Core`
  """

  alias OMG.Eth
  alias OMG.Recorder
  alias OMG.RootChainCoordinator.Core

  use GenServer
  use OMG.LoggerExt

  defmodule SyncGuide do
    @moduledoc """
    A guiding message to a coordinated service. Tells until which root chain height it is safe to advance syncing to.

    `sync_height` - until where it is safe to process the root chain
    `root_chain_height` - until where it is safe to pre-fetch and cache the events from the root chain
    """

    defstruct [:root_chain_height, :sync_height]

    @type t() :: %__MODULE__{
            root_chain_height: non_neg_integer(),
            sync_height: non_neg_integer()
          }
  end

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
  @spec get_sync_info() :: SyncGuide.t() | :nosync
  def get_sync_info do
    GenServer.call(__MODULE__, :get_sync_info)
  end

  def init(configs_services) do
    {:ok, configs_services, {:continue, :setup}}
  end

  def handle_continue(:setup, configs_services) do
    _ = Logger.info("Starting #{__MODULE__} service.")
    :ok = Eth.node_ready()
    {:ok, rootchain_height} = Eth.get_ethereum_height()
    height_check_interval = Application.fetch_env!(:omg, :coordinator_eth_height_check_interval_ms)
    {:ok, _} = schedule_get_ethereum_height(height_check_interval)
    state = Core.init(configs_services, rootchain_height)

    configs_services
    |> Map.keys()
    |> request_sync()

    {:ok, _} = Recorder.start_link(%Recorder{name: __MODULE__.Recorder, parent: self()})

    {:noreply, state}
  end

  def handle_call({:check_in, synced_height, service_name}, {pid, _}, state) do
    _ = Logger.debug("#{inspect(service_name)} checks in on height #{inspect(synced_height)}")
    {:ok, state} = Core.check_in(state, pid, synced_height, service_name)
    {:reply, :ok, state, 60_000}
  end

  def handle_call(:get_sync_info, {pid, _}, state) do
    {:reply, Core.get_synced_info(state, pid), state}
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
    _ = Logger.warn("No new activity for 60 seconds. Are we dead?")
    {:noreply, state}
  end

  defp schedule_get_ethereum_height(interval) do
    :timer.send_interval(interval, self(), :update_root_chain_height)
  end

  defp request_sync(services) do
    Enum.each(services, fn service -> safe_send(service, :sync) end)
  end

  defp safe_send(registered_name_or_pid, msg) do
    send(registered_name_or_pid, msg)
  rescue
    ArgumentError ->
      msg
  end
end

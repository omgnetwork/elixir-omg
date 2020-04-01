# Copyright 2019-2020 OmiseGO Pte Ltd
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

  alias OMG.Eth.EthereumHeight
  alias OMG.RootChainCoordinator.Core

  use GenServer
  use OMG.Utils.LoggerExt
  use Spandex.Decorators

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
  @decorate span(service: :ethereum_event_listener, type: :backend, name: "check_in/2")
  @spec check_in(non_neg_integer(), atom()) :: :ok
  def check_in(synced_height, service_name) do
    GenServer.call(__MODULE__, {:check_in, synced_height, service_name})
  end

  @doc """
  Gets Ethereum height that services can synchronize up to.
  """
  @decorate span(service: :ethereum_event_listener, type: :backend, name: "get_sync_info/0")
  @spec get_sync_info() :: SyncGuide.t() | :nosync
  def get_sync_info() do
    GenServer.call(__MODULE__, :get_sync_info)
  end

  @doc """
  Gets all the current synced height for all the services checked in
  """
  @spec get_ethereum_heights() :: {:ok, Core.ethereum_heights_result_t()}
  def get_ethereum_heights() do
    GenServer.call(__MODULE__, :get_ethereum_heights)
  end

  def init({args, configs_services}) do
    {:ok, {args, configs_services}, {:continue, :setup}}
  end

  def handle_continue(:setup, {args, configs_services}) do
    _ = Logger.info("Starting #{__MODULE__} service. #{inspect({args, configs_services})}")
    metrics_collection_interval = Keyword.fetch!(args, :metrics_collection_interval)
    coordinator_eth_height_check_interval_ms = Keyword.fetch!(args, :coordinator_eth_height_check_interval_ms)
    {:ok, rootchain_height} = EthereumHeight.get()
    {:ok, _} = schedule_get_ethereum_height(coordinator_eth_height_check_interval_ms)
    state = Core.init(configs_services, rootchain_height)

    configs_services
    |> Map.keys()
    |> request_sync()

    {:ok, _} = :timer.send_interval(metrics_collection_interval, self(), :send_metrics)

    _ = Logger.info("Started #{inspect(__MODULE__)}")

    {:noreply, state}
  end

  def handle_info(:send_metrics, state) do
    :ok = :telemetry.execute([:process, __MODULE__], %{}, state)
    {:noreply, state}
  end

  def handle_info(:update_root_chain_height, state) do
    {:ok, root_chain_height} = EthereumHeight.get()
    {:ok, state} = Core.update_root_chain_height(state, root_chain_height)
    {:noreply, state}
  end

  def handle_info({:DOWN, _ref, :process, pid, _}, state) do
    {:ok, state} = Core.check_out(state, pid)
    {:noreply, state}
  end

  def handle_call({:check_in, synced_height, service_name}, {pid, _ref}, state) do
    #_ = Logger.debug("#{inspect(service_name)} checks in on height #{inspect(synced_height)}")

    {:ok, state} = Core.check_in(state, pid, synced_height, service_name)
    {:reply, :ok, state}
  end

  def handle_call(:get_sync_info, {pid, _}, state) do
    {:reply, Core.get_synced_info(state, pid), state}
  end

  def handle_call(:get_ethereum_heights, _from, state) do
    {:reply, {:ok, Core.get_ethereum_heights(state)}, state}
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

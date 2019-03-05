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

defmodule OMG.API.Supervisor do
  @moduledoc """
   OMG.API top level supervisor.
  """
  use Supervisor
  use OMG.API.LoggerExt

  def start_link do
    Supervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(:ok) do
    DeferredConfig.populate(:omg_api)

    monitor_children = [
      {OMG.API.State, []},
      {OMG.API.BlockQueue.Server, []},
      {OMG.API.FreshBlocks, []},
      {OMG.API.FeeServer, []},
      {OMG.API.RootChainCoordinator, coordinator_setup()},
      OMG.API.EthereumEventListener.prepare_child(
        service_name: :depositor,
        synced_height_update_key: :last_depositor_eth_height,
        get_events_callback: &OMG.Eth.RootChain.get_deposits/2,
        process_events_callback: &OMG.API.State.deposit/1
      ),
      OMG.API.EthereumEventListener.prepare_child(
        service_name: :in_flight_exit,
        synced_height_update_key: :last_in_flight_exit_eth_height,
        get_events_callback: &OMG.Eth.RootChain.get_in_flight_exit_starts/2,
        process_events_callback: &ignore_validities/1
      ),
      OMG.API.EthereumEventListener.prepare_child(
        service_name: :piggyback,
        synced_height_update_key: :last_piggyback_exit_eth_height,
        get_events_callback: &OMG.Eth.RootChain.get_piggybacks/2,
        process_events_callback: &ignore_validities/1
      ),
      OMG.API.EthereumEventListener.prepare_child(
        service_name: :exiter,
        synced_height_update_key: :last_exiter_eth_height,
        get_events_callback: &OMG.Eth.RootChain.get_standard_exits/2,
        process_events_callback: fn exits ->
          exits =
            Enum.map(exits, fn %{exit_id: exit_id} ->
              {:ok, {_, _, _, position}} = OMG.Eth.RootChain.get_standard_exit(exit_id)
              OMG.API.Utxo.Position.decode(position)
            end)

          ignore_validities(exits)
        end
      ),
      {OMG.RPC.Web.Endpoint, []}
    ]

    children = [
      {OMG.API.GethMonitor, []},
      {OMG.API.Monitor, monitor_children}
    ]

    opts = [strategy: :one_for_one, max_restarts: 1000, max_seconds: 60]

    _ = Logger.info("Starting #{inspect(__MODULE__)}")
    :ok = :error_logger.add_report_handler(Sentry.Logger)
    Supervisor.init(children, opts)
  end

  def coordinator_setup do
    deposit_finality_margin = Application.fetch_env!(:omg_api, :deposit_finality_margin)

    %{
      depositor: [finality_margin: deposit_finality_margin],
      exiter: [waits_for: :depositor, finality_margin: 0],
      in_flight_exit: [waits_for: :depositor, finality_margin: 0],
      piggyback: [waits_for: :in_flight_exit, finality_margin: 0]
    }
  end

  defp ignore_validities(exits) do
    {status, db_updates, _validities} = OMG.API.State.exit_utxos(exits)
    {status, db_updates}
  end
end

# Copyright 2019 OmiseGO Pte Ltd
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

defmodule OMG.ChildChain.SyncSupervisor do
  @moduledoc """
  Supervises the remainder (i.e. all except the `Watcher.BlockGetter` + `OMG.State` pair, supervised elsewhere)
  of the Watcher app
  """
  use Supervisor
  use OMG.Utils.LoggerExt

  alias OMG.ChildChain.CoordinatorSetup
  alias OMG.Eth.RootChain
  alias OMG.EthereumEventListener
  alias OMG.RootChainCoordinator
  alias OMG.State

  def start_link do
    Supervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(:ok) do
    opts = [strategy: :one_for_one]

    _ = Logger.info("Starting #{inspect(__MODULE__)}")
    Supervisor.init(children(), opts)
  end

  defp children() do
    [
      {OMG.ChildChain.BlockQueue.Server, []},
      {RootChainCoordinator, CoordinatorSetup.coordinator_setup()},
      EthereumEventListener.prepare_child(
        service_name: :depositor,
        synced_height_update_key: :last_depositor_eth_height,
        get_events_callback: &RootChain.get_deposits/2,
        process_events_callback: &State.deposit/1
      ),
      EthereumEventListener.prepare_child(
        service_name: :in_flight_exit,
        synced_height_update_key: :last_in_flight_exit_eth_height,
        get_events_callback: &RootChain.get_in_flight_exit_starts/2,
        process_events_callback: &exit_and_ignore_validities/1
      ),
      EthereumEventListener.prepare_child(
        service_name: :piggyback,
        synced_height_update_key: :last_piggyback_exit_eth_height,
        get_events_callback: &RootChain.get_piggybacks/2,
        process_events_callback: &exit_and_ignore_validities/1
      ),
      EthereumEventListener.prepare_child(
        service_name: :exiter,
        synced_height_update_key: :last_exiter_eth_height,
        get_events_callback: &RootChain.get_standard_exits/2,
        process_events_callback: &exit_and_ignore_validities/1
      )
    ]
  end

  defp exit_and_ignore_validities(exits) do
    {status, db_updates, _validities} = State.exit_utxos(exits)
    {status, db_updates}
  end
end

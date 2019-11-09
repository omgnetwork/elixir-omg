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

defmodule OMG.Watcher.SyncSupervisor do
  @moduledoc """
  Supervises the remainder (i.e. all except the `Watcher.BlockGetter` + `OMG.State` pair, supervised elsewhere)
  of the Watcher app
  """
  use Supervisor
  use OMG.Utils.LoggerExt

  alias OMG.Eth
  alias OMG.EthereumEventListener
  alias OMG.Watcher

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
      # this instance of the listener sends deposits to be consumed by the convenience API
      EthereumEventListener.prepare_child(
        service_name: :convenience_deposit_processor,
        synced_height_update_key: :last_convenience_deposit_processor_eth_height,
        get_events_callback: &Eth.RootChain.get_deposits/2,
        process_events_callback: fn deposits ->
          Watcher.DB.EthEvent.insert_deposits!(deposits)
          {:ok, []}
        end
      ),

      # this instance of the listener sends exits to be consumed by the convenience API
      # we shouldn't use :exit_processor for this, as it has different waiting semantics (waits more)
      EthereumEventListener.prepare_child(
        service_name: :convenience_exit_processor,
        synced_height_update_key: :last_convenience_exit_processor_eth_height,
        get_events_callback: &Eth.RootChain.get_standard_exits/2,
        process_events_callback: fn exits ->
          Watcher.DB.EthEvent.insert_exits!(exits)
          {:ok, []}
        end
      )
    ]
  end
end

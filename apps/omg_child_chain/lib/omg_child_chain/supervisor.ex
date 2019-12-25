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

defmodule OMG.ChildChain.Supervisor do
  @moduledoc """
   OMG.ChildChain top level supervisor.
  """
  use Supervisor
  use OMG.Utils.LoggerExt
  alias OMG.ChildChain.FeeServer
  alias OMG.ChildChain.FreshBlocks
  alias OMG.ChildChain.Monitor
  alias OMG.ChildChain.SyncSupervisor
  alias OMG.Eth.RootChain
  alias OMG.State
  alias OMG.Status.Alert.Alarm

  def start_link do
    Supervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(:ok) do
    # prevent booting if contracts are not ready
    :ok = RootChain.contract_ready()
    {:ok, _contract_deployment_height} = RootChain.get_root_deployment_height()

    children = [
      {State, []},
      {FreshBlocks, []},
      {FeeServer, []},
      {Monitor,
       [
         Alarm,
         %{
           id: SyncSupervisor,
           start: {SyncSupervisor, :start_link, []},
           restart: :permanent,
           type: :supervisor
         }
       ]}
    ]

    opts = [strategy: :one_for_one]

    _ = Logger.info("Starting #{inspect(__MODULE__)}")
    Supervisor.init(children, opts)
  end
end

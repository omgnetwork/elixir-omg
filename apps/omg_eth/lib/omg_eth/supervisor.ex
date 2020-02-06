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

defmodule OMG.Eth.Supervisor do
  @moduledoc """
   OMG Eth top level supervisor is supervising connection monitor towards Eth clients and
   a gen server that serves as a unified view of reported block height (`OMG.Eth.EthereumHeight`).
  """
  use Supervisor
  alias OMG.Status.Alert.Alarm
  require Logger

  def start_link() do
    Supervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(:ok) do
    children = [
      {OMG.Eth.EthereumClientMonitor,
       [
         alarm_module: Alarm,
         event_bus: OMG.Bus,
         ws_url: Application.get_env(:omg_eth, :ws_url)
       ]},
      {OMG.Eth.EthereumHeight, [event_bus: OMG.Bus]}
    ]

    opts = [strategy: :one_for_one]

    _ = Logger.info("Starting #{inspect(__MODULE__)}")
    Supervisor.init(children, opts)
  end
end

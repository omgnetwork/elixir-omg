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

defmodule OMG.Sup do
  @moduledoc """
   OMG top level supervisor.
  """
  use Supervisor
  use OMG.LoggerExt
  alias OMG.Alert.Alarm

  def start_link do
    Supervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(:ok) do
    children = [
      {OMG.EthereumClientMonitor, [Alarm]}
    ]

    opts = [strategy: :one_for_one]

    _ = Logger.info("Starting #{inspect(__MODULE__)}")
    Supervisor.init(children, opts)
  end
end

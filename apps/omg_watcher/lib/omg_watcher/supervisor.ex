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

defmodule OmgWatcher.Supervisor do
  @moduledoc """
  Supervises the remainder (i.e. all except the `OmgWatcher.BlockGetter` + `OMG.State` pair, supervised elsewhere)
  of the Watcher app
  """
  use Supervisor
  use OMG.LoggerExt

  alias OmgWatcher

  def start_link do
    Supervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(:ok) do
    children = [
      {OMG.InternalEventBus, []},
      # Start the Ecto repository
      %{
        id: OmgWatcher.DB.Repo,
        start: {OmgWatcher.DB.Repo, :start_link, []},
        type: :supervisor
      },
      %{
        id: OmgWatcher.SyncSupervisor,
        start: {OmgWatcher.SyncSupervisor, :start_link, []},
        restart: :permanent,
        type: :supervisor
      },
      # Start workers
      {OmgWatcher.Eventer, []},
      # Start the endpoint when the application starts
      %{
        id: OmgWatcher.Web.Endpoint,
        start: {OmgWatcher.Web.Endpoint, :start_link, []},
        type: :supervisor
      }
    ]

    opts = [strategy: :one_for_one]

    _ = Logger.info("Starting #{inspect(__MODULE__)}")
    Supervisor.init(children, opts)
  end
end

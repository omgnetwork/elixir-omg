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

defmodule OMG.Watcher.Supervisor do
  @moduledoc """
  Supervises the remainder (i.e. all except the `Watcher.BlockGetter` + `OMG.State` pair, supervised elsewhere)
  of the Watcher app
  """
  use Supervisor
  use OMG.Utils.LoggerExt

  alias OMG.Status.Alert.Alarm
  alias OMG.Watcher
  alias OMG.Watcher.Monitor
  alias OMG.Watcher.SyncSupervisor

  if Mix.env() == :test do
    defmodule Sandbox do
      @moduledoc """
       Must be start after Watcher.DB.Repo,
       that no data will be downloaded/inserted before setting the sandbox option.
      """
      use GenServer
      alias Ecto.Adapters.SQL

      def start_link(_args) do
        GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
      end

      def init(stack) do
        :ok = SQL.Sandbox.checkout(Watcher.DB.Repo)
        SQL.Sandbox.mode(Watcher.DB.Repo, {:shared, self()})
        {:ok, stack}
      end
    end
  end

  @children_run_after_repo if(Mix.env() == :test, do: [{__MODULE__.Sandbox, []}], else: [])

  def start_link do
    Supervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(:ok) do
    # why sandbox is in this code
    # https://github.com/omisego/elixir-omg/pull/562
    top_children =
      [
        %{
          id: Watcher.DB.Repo,
          start: {Watcher.DB.Repo, :start_link, []},
          type: :supervisor
        }
      ] ++ @children_run_after_repo

    children = [
      {Monitor,
       [
         Alarm,
         [
           %{
             id: SyncSupervisor,
             start: {SyncSupervisor, :start_link, []},
             restart: :permanent,
             type: :supervisor
           }
         ]
       ]},
      # Start workers
      # {Watcher.Eventer, []},
      {OMG.Watcher.BlockApplicationConsumer, []}
    ]

    opts = [strategy: :one_for_one]
    _ = Logger.info("Starting #{inspect(__MODULE__)}")
    Supervisor.init(top_children ++ children, opts)
  end
end

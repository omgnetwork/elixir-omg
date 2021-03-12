# Copyright 2019-2020 OMG Network Pte Ltd
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

defmodule OMG.WatcherInfo.Supervisor do
  @moduledoc """
  Starts and supervises Watcher Informational services such as the watcher informational database,
  block consumer, deposit consumer, exit consumer, etc.
  """
  use Supervisor
  use OMG.Utils.LoggerExt

  alias OMG.WatcherInfo

  if Mix.env() == :test do
    defmodule Sandbox do
      @moduledoc """
      Must be start after WatcherInfo.DB.Repo,
      that no data will be downloaded/inserted before setting the sandbox option.
      """
      use GenServer
      alias Ecto.Adapters.SQL

      def start_link(_args) do
        GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
      end

      def init(stack) do
        :ok = SQL.Sandbox.checkout(WatcherInfo.DB.Repo)
        SQL.Sandbox.mode(WatcherInfo.DB.Repo, {:shared, self()})
        {:ok, stack}
      end
    end
  end

  @children_run_after_repo if(Mix.env() == :test, do: [{__MODULE__.Sandbox, []}], else: [])

  def start_link() do
    Supervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(:ok) do
    # why sandbox is in this code
    # https://github.com/omgnetwork/elixir-omg/pull/562
    top_children =
      [
        %{
          id: WatcherInfo.DB.Repo,
          start: {WatcherInfo.DB.Repo, :start_link, []},
          type: :supervisor
        }
      ] ++ @children_run_after_repo

    opts = [strategy: :one_for_one]
    _ = Logger.info("Starting #{inspect(__MODULE__)}")
    Supervisor.init(top_children, opts)
  end
end

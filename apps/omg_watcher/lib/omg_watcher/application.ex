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

defmodule OMG.Watcher.Application do
  @moduledoc false
  use Application
  require Logger

  def start(_type, _args) do
    DeferredConfig.populate(:omg_watcher)
    cookie = System.get_env("ERL_W_COOKIE")
    :ok = set_cookie(cookie)

    _ = Logger.info("Starting #{inspect(__MODULE__)}")

    start_root_supervisor()
  end

  def start_root_supervisor do
    # root supervisor must stop whenever any of its children supervisors goes down (children carry the load of restarts)
    children = [
      %{
        id: OMG.Watcher.Supervisor,
        start: {OMG.Watcher.Supervisor, :start_link, []},
        restart: :permanent,
        type: :supervisor
      }
    ]

    opts = [
      strategy: :one_for_one,
      # whenever any of supervisor's children goes down, so it does
      max_restarts: 0,
      name: OMG.Watcher.RootSupervisor
    ]

    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    OMG.Watcher.Web.Endpoint.config_change(changed, removed)
    :ok
  end

  defp set_cookie(cookie) when is_binary(cookie) do
    cookie
    |> String.to_atom()
    |> Node.set_cookie()
  end

  defp set_cookie(_), do: _ = Logger.warn("Cookie not applied.")
end

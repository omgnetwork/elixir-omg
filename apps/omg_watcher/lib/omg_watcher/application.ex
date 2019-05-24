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

defmodule OMG.Watcher.Application do
  @moduledoc false
  use Application
  use OMG.Utils.LoggerExt

  def start(_type, _args) do
    DeferredConfig.populate(:omg_watcher)
    cookie = System.get_env("ERL_W_COOKIE")
    true = set_cookie(cookie)
    :ok = set_code_reloading()
    _ = Logger.info("Starting #{inspect(__MODULE__)}")

    _ =
      :telemetry.attach(
        "appsignal-ecto",
        [:omg_watcher, :repo, :query],
        &Appsignal.Ecto.handle_event/4,
        nil
      )

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

  defp set_cookie(_), do: :ok == Logger.warn("Cookie not applied.")

  defp set_code_reloading do
    if Code.ensure_loaded?(IEx) and IEx.started?() do
      :ok
    else
      old = Application.get_env(:omg_watcher, OMG.Watcher.Web.Endpoint)
      Application.put_env(:omg_watcher, OMG.Watcher.Web.Endpoint, Keyword.put(old, :code_reloader, false))
    end
  end
end

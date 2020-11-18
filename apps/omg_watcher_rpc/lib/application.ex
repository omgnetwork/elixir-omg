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

defmodule OMG.WatcherRPC.Application do
  @moduledoc false
  use Application
  use OMG.Utils.LoggerExt

  def start(_type, _args) do
    _ = Logger.info("Starting #{inspect(__MODULE__)}")

    start_root_supervisor()
  end

  def start_root_supervisor() do
    # root supervisor must stop whenever any of its children supervisors goes down (children carry the load of restarts)

    _ =
      SpandexPhoenix.Telemetry.install(
        endpoint_telemetry_prefix: [:watcher_rpc, :endpoint],
        tracer: OMG.WatcherRPC.Tracer,
        customize_metadata: &OMG.WatcherRPC.Tracer.add_trace_metadata/1
      )

    children = [
      %{
        id: OMG.WatcherRPC.Web.Endpoint,
        start: {OMG.WatcherRPC.Web.Endpoint, :start_link, []},
        type: :supervisor
      }
    ]

    opts = [
      strategy: :one_for_one,
      # whenever any of supervisor's children goes down, so it does
      name: OMG.WatcherRPC.RootSupervisor
    ]

    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    OMG.WatcherRPC.Web.Endpoint.config_change(changed, removed)
    :ok
  end
end

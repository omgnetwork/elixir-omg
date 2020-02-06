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

defmodule OMG.WatcherInfo.Application do
  @moduledoc false
  use Application
  use OMG.Utils.LoggerExt

  def start(_type, _args) do
    _ = Logger.info("Starting #{inspect(__MODULE__)}")

    start_root_supervisor()
  end

  def start_root_supervisor() do
    # root supervisor must stop whenever any of its children supervisors goes down (children carry the load of restarts)
    children = [
      %{
        id: OMG.WatcherInfo.Supervisor,
        start: {OMG.WatcherInfo.Supervisor, :start_link, []},
        restart: :permanent,
        type: :supervisor
      }
    ]

    opts = [
      strategy: :one_for_one,
      # whenever any of supervisor's children goes down, so it does
      max_restarts: 0,
      name: OMG.WatcherInfo.RootSupervisor
    ]

    Supervisor.start_link(children, opts)
  end
end

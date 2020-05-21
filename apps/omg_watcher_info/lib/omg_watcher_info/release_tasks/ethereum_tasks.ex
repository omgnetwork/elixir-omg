# Copyright 2019-2019 OmiseGO Pte Ltd
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

defmodule OMG.WatcherInfo.ReleaseTasks.EthereumTasks do
  @moduledoc """
  Some updates to data persisted in the `watcher-info` database requires calls to the root chain.
  This module serves the purpose of running such database updates at release.
  A task can be "retired" (or not) once there all environments have updated.

  N.B. A release task was chosen over a migration considering:
   1. Risks associated with coupling a migration to particular dependencies - e.g. Ethereumex
   2. Expectation that we will want to update the database from root chain data every once in a while.
  """
  require Logger
  @app :omg_watcher_info

  alias OMG.WatcherInfo.ReleaseTasks.EthereumTasks.{AddEthereumHeightToEthEvents}

  def run() do
    _ = Application.ensure_all_started(@app)

    # Run Ethereum tasks
    AddEthereumHeightToEthEvents.run()
  end
end

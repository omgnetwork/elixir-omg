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
  Some updates to data persisted in the `watcher-info` database require making calls to Ethereum.

  This task executes such updates. Currently, the only update is the addition of `eth_height`, but
  we anticipate that the need for database updates from Ethereum will arise in the future.

  Each update would make changes to the database ONCE per environment. For example, if no `ethevent`
  has an `eth_height` of `nil`, no Ethereum calls and subsequent database updates will be made, though
  a database query will check this condition at each deploy.

  An update can be "removed" once all environments have updated.

  A release task was chosen over a migration due to the risk associated with coupling a migration to
  Ethereumex.
  """
  require Logger
  @app :omg_watcher_info

  alias OMG.WatcherInfo.ReleaseTasks.EthereumTasks

  def run() do
    _ = Application.ensure_all_started(@app)

    # Run Ethereum tasks
    EthereumTasks.AddEthereumHeightToEthEvents.run()
  end
end

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

defmodule OMG.Watcher.Depositor do
  @moduledoc """
  Allows to extend Watcher's event handler for deposits
  """
  alias OMG.State

  @doc """
  Processes a deposit event, introducing a UTXO into the ledger.
  Note: it has to return whatever `State.deposits` returns to process deposits by the Watcher.
  """
  @spec new_deposits([OMG.State.Core.deposit()]) :: {:ok, list(State.Core.db_update())}
  def new_deposits(deposits) do
    if Code.ensure_loaded?(OMG.WatcherInfo.DB.EthEvent),
      do: Kernel.apply(OMG.WatcherInfo.DB.EthEvent, :insert_deposits!, [deposits])

    State.deposit(deposits)
  end
end

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

defmodule OMG.Watcher.ExitProcessor.UpdateDB.NewExits do
  @moduledoc """
  Functions related to the logic on updating DB for 'new exit' events.
  The event happens whenever a standard exit happens on the root chain.
  """

  alias OMG.Watcher.ExitProcessor.ExitInfo

  @doc """
  DB updates needed to add new exits from Ethereum events into tracked state.

  The list of `exit_contract_statuses` is used to track current (as in wall-clock "now", not syncing "now") status.
  This is to prevent spurious invalid exit events being fired during syncing for exits that were challenged/finalized
  Still we do want to track these exits when syncing, to have them spend from `OMG.State` on their finalization
  """
  @spec get_db_updates(list(map()), list(map)) :: {:ok, list()} | {:error, :unexpected_events}
  def get_db_updates(new_exits, exit_contract_statuses)

  def get_db_updates(new_exits, exit_contract_statuses) when length(new_exits) != length(exit_contract_statuses) do
    {:error, :unexpected_events}
  end

  def get_db_updates(new_exits, exit_contract_statuses) do
    new_exits_kv_pairs =
      new_exits
      |> Enum.zip(exit_contract_statuses)
      |> Enum.map(fn {event, contract_status} ->
        {ExitInfo.new_key(contract_status, event), ExitInfo.new(contract_status, event)}
      end)

    db_updates = new_exits_kv_pairs |> Enum.map(&ExitInfo.make_db_update/1)

    {:ok, db_updates}
  end
end

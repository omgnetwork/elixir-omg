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

defmodule OMG.Watcher.ExitProcessor.UpdateDB.NewInflightExits do
  @moduledoc """
  Functions related to the logic on updating DB for 'new inflight exit' events.
  The event happens whenever an in-flight exit happens on the root chain.
  """

  alias OMG.Watcher.ExitProcessor.InFlightExitInfo

  @type new_in_flight_exit_status_t() :: {tuple(), pos_integer()}

  @doc """
  Add new in flight exits from Ethereum events into tracked state.
  """
  @spec get_db_update(list(map()), list(new_in_flight_exit_status_t())) ::
          {:ok, list()} | {:error, :unexpected_events}
  def get_db_update(new_ifes_events, contract_statuses)

  def get_db_update(new_ifes_events, contract_statuses)
      when length(new_ifes_events) != length(contract_statuses),
      do: {:error, :unexpected_events}

  def get_db_update(new_ifes_events, contract_statuses) do
    db_updates =
      new_ifes_events
      |> Enum.zip(contract_statuses)
      |> Enum.map(fn {event, contract_status} -> InFlightExitInfo.new_kv(event, contract_status) end)
      |> Enum.map(&InFlightExitInfo.make_db_update/1)

    {:ok, db_updates}
  end
end

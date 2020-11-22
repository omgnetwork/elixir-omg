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

defmodule OMG.StateTest do
  @moduledoc """
  Smoke tests the imperative shell - runs a happy path on `OMG.State`. Logic tested elsewhere
  """
  use ExUnitFixtures
  use ExUnit.Case, async: false

  use OMG.DB.Fixtures

  alias OMG.State
  alias OMG.TestHelper
  alias OMG.Utxo

  require Utxo

  @eth OMG.Eth.zero_address()
  @fee_claimer_address Base.decode16!("DEAD000000000000000000000000000000000000")

  deffixture standalone_state_server(db_initialized) do
    # match variables to hide "unused var" warnings (can't be fixed by underscoring in line above, breaks macro):
    _ = db_initialized
    # need to override that to very often, so that many checks fall in between a single child chain block submission
    {:ok, started_apps} = Application.ensure_all_started(:omg_db)
    # the pubsub is required, because `OMG.State` is broadcasting to the `OMG.Bus`
    {:ok, bus_apps} = Application.ensure_all_started(:omg_bus)

    on_exit(fn ->
      (started_apps ++ bus_apps)
      |> Enum.reverse()
      |> Enum.map(fn app -> :ok = Application.stop(app) end)
    end)

    child_block_interval = OMG.Eth.Configuration.child_block_interval()
    metrics_collection_interval = 60_000

    {:ok, _} =
      Supervisor.start_link(
        [
          {OMG.State,
           [
             fee_claimer_address: @fee_claimer_address,
             child_block_interval: child_block_interval,
             metrics_collection_interval: metrics_collection_interval
           ]}
        ],
        strategy: :one_for_one
      )

    :ok
  end
end

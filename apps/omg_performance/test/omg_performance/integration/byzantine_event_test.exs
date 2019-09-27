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

defmodule OMG.Performance.ByzantineEventsTest do
  use ExUnitFixtures
  use ExUnit.Case, async: false
  use OMG.ChildChain.Integration.Fixtures
  use OMG.Watcher.Fixtures

  alias OMG.Performance
  alias OMG.Performance.ByzantineEvents
  alias OMG.Performance.ByzantineEvents.Generators

  @moduletag :integration
  @moduletag timeout: 180_000

  setup_all do
    Application.put_env(:omg_child_chain, :mix_env, "dev")
    Application.put_env(:omg_watcher, :mix_env, "dev")

    on_exit(fn ->
      Application.put_env(:omg_child_chain, :mix_env, nil)
      Application.put_env(:omg_watcher, :mix_env, nil)
    end)

    :ok
  end

  @tag fixtures: [:contract, :child_chain, :omg_watcher]
  test "time response for asking for exit data", %{contract: %{contract_addr: contract}} do
    exiting_users = 3
    ntx_to_send = 15
    spenders = Generators.generate_users(2)
    exits_per_user = length(spenders) * ntx_to_send
    total_exits = length(spenders) * ntx_to_send * exiting_users

    Performance.start_extended_perftest(ntx_to_send, spenders, contract)
    # get exit position from child chain, blocking call
    exit_positions = Generators.stream_utxo_positions() |> Enum.take(exits_per_user)
    # wait before asking watcher about exit data
    ByzantineEvents.watcher_synchronize()

    statistics = ByzantineEvents.start_dos_get_exits(exit_positions, exiting_users)

    correct_exits = statistics |> Enum.map(&Map.get(&1, :corrects_count)) |> Enum.sum()
    error_exits = statistics |> Enum.map(&Map.get(&1, :errors_count)) |> Enum.sum()

    assert total_exits == correct_exits + error_exits
    assert error_exits == 0
  end
end

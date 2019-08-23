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
  alias OMG.Watcher.TestHelper

  @moduletag :integration

  @tag fixtures: [:contract, :child_chain, :watcher]
  test "time response for asking for exit data", %{contract: %{contract_addr: contract}} do
    dos_users = 10
    ntx_to_send = 100
    spenders = ByzantineEvents.generate_users(2)
    exit_per_dos = length(spenders) * ntx_to_send
    total_exits = length(spenders) * ntx_to_send * dos_users

    IO.puts("""
    dos users: #{dos_users}
    spenders: #{length(spenders)}
    ntx_toxend: #{ntx_to_send}
    exits per dos user: #{exit_per_dos}
    total exits: #{total_exits}
    """)

    Performance.start_extended_perftest(ntx_to_send, spenders, contract)
    # get exit position from child chain, blocking call
    exit_positions = ByzantineEvents.stream_tx_positions() |> Enum.take(exit_per_dos)
    # wait before asking watcher about exit data
    TestHelper.watcher_synchronize()

    statistics = ByzantineEvents.start_dos_get_exits(dos_users, exit_positions)

    times = statistics |> Enum.map(&Map.get(&1, :time))
    correct_exits = statistics |> Enum.map(&Map.get(&1, :correct)) |> Enum.sum()
    error_exits = statistics |> Enum.map(&Map.get(&1, :error)) |> Enum.sum()

    IO.puts("""
    max dos user time: #{Enum.max(times) / 1_000_000} s
    min dos user time: #{Enum.min(times) / 1_000_000} s
    average dos user time: #{Enum.sum(times) / dos_users / 1_000_000} s
    time per exit: #{Enum.sum(times) / total_exits / 1_000_000} s
    correct exits: #{correct_exits}
    error exits: #{error_exits}
    """)

    assert error_exits == 0
  end
end

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

  alias OMG.Eth
  alias OMG.Performance
  alias OMG.Performance.ByzantineEvents
  alias OMG.Performance.ByzantineEvents.Generators
  alias OMG.Utils.HttpRPC.Client

  @moduletag :integration
  @moduletag timeout: 180_000
  @watcher_url Application.get_env(:byzantine_events, :watcher_url)

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
    dos_users = 3
    ntx_to_send = 100
    spenders = Generators.generate_users(4)
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
    exit_positions = Generators.stream_utxo_positions() |> Enum.take(exit_per_dos)
    # wait before asking watcher about exit data
    ByzantineEvents.watcher_synchronize()

    statistics = ByzantineEvents.start_dos_get_exits(dos_users, exit_positions)

    times = statistics |> Enum.map(&Map.get(&1, :time))
    correct_exits = statistics |> Enum.map(&Map.get(&1, :corrects_count)) |> Enum.sum()
    error_exits = statistics |> Enum.map(&Map.get(&1, :errors_count)) |> Enum.sum()

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

  @tag fixtures: [:contract, :child_chain, :omg_watcher]
  test "watcher catch all non_canonical_ife", %{contract: %{contract_addr: contract}} do
    dos_users = 2
    ntx_to_send = 10
    spenders = Generators.generate_users(3)
    ife_per_dos = length(spenders) * ntx_to_send

    OMG.Performance.start_extended_perftest(ntx_to_send, spenders, contract)
    binary_txs = Generators.stream_txs() |> Enum.take(ife_per_dos)
    utxos = spenders |> Enum.map(fn spender -> ByzantineEvents.get_exitable_utxos(spender) end) |> Enum.concat()

    ByzantineEvents.watcher_synchronize()
    dos_result = ByzantineEvents.start_dos_non_canonical_ife(dos_users, binary_txs, utxos, spenders)
    started_ife = Enum.reduce(dos_result, 0, fn %{started_ife_count: start_ife}, acc -> start_ife + acc end)

    {:ok, ethereum_height} = Eth.get_ethereum_height()
    ByzantineEvents.watcher_synchronize_service("in_flight_exit_processor", ethereum_height)

    {:ok, %{byzantine_events: byzantine_events}} = Client.get_status(@watcher_url)
    non_canonical_ife = Enum.filter(byzantine_events, &match?(%{"event" => "non_canonical_ife"}, &1))

    assert length(non_canonical_ife) == started_ife
  end
end

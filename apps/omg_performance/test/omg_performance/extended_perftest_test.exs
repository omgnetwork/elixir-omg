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

defmodule OMG.Performance.ExtendedPerftestTest do
  @moduledoc """
  Simple smoke testing of the performance test
  """

  use ExUnitFixtures
  use ExUnit.Case, async: false
  use OMG.ChildChain.Integration.Fixtures

  use OMG.Performance

  @moduletag :integration
  @moduletag :common

  # NOTE: still bound to fixtures :(, because of the child chain setup, but this will go eventually, so leaving as is
  deffixture perf_test(contract) do
    _ = contract
    :ok = Performance.init()
    {:ok, destdir} = Briefly.create(directory: true, prefix: "temp_results")
    {:ok, %{destdir: destdir}}
  end

  @tag fixtures: [:perf_test, :in_beam_child_chain]
  @tag timeout: 120_000
  test "Smoke test - run start_extended_perf and see if it doesn't crash", %{perf_test: {:ok, %{destdir: destdir}}} do
    # 3000 txs sending 1 each, plus 1 for fees
    ntxs = 3000
    senders = Generators.generate_users(2)

    assert :ok = Performance.ExtendedPerftest.start(ntxs, senders, destdir: destdir)

    assert ["perf_result" <> _ = perf_result] = File.ls!(destdir)
    smoke_test_statistics(Path.join(destdir, perf_result), ntxs * length(senders))
  end

  defp smoke_test_statistics(path, expected_txs) do
    assert {:ok, stats} = Jason.decode(File.read!(path))

    txs_count =
      stats
      |> Enum.map(fn entry -> entry["txs"] end)
      |> Enum.sum()

    assert txs_count == expected_txs
  end
end

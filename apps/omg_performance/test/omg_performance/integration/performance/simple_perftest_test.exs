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

defmodule OMG.Performance.SimplePerftestTest do
  @moduledoc """
  Simple smoke testing of the performance test
  """

  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  use OMG.Performance

  @moduletag :integration
  @moduletag :common

  setup do
    :ok = Performance.init()
    {:ok, destdir} = Briefly.create(directory: true, prefix: "temp_results")
    {:ok, %{destdir: destdir}}
  end

  test "Smoke test - run start_simple_perf and see if it doesn't crash", %{destdir: destdir} do
    ntxs = 3000
    nsenders = 2
    assert :ok = Performance.SimplePerftest.start(ntxs, nsenders, %{destdir: destdir})

    assert ["perf_result" <> _ = perf_result] = File.ls!(destdir)
    smoke_test_statistics(Path.join(destdir, perf_result), ntxs * nsenders)
  end

  test "Smoke test - run start_simple_perf and see if it doesn't crash - with profiling", %{destdir: destdir} do
    ntxs = 3
    nsenders = 2

    fprof_io =
      capture_io(fn ->
        assert :ok = Performance.SimplePerftest.start(ntxs, nsenders, %{destdir: destdir, profile: true})
      end)

    assert fprof_io =~ "Done!"

    assert ["perf_result" <> _ = prof_results, "perf_result" <> _ = perf_results] = Enum.sort(File.ls!(destdir))
    smoke_test_profiling(Path.join(destdir, prof_results))
    smoke_test_statistics(Path.join(destdir, perf_results), ntxs * nsenders)
  end

  test "Smoke test - run start_simple_perf and see if it doesn't crash - overiding block creation", %{destdir: destdir} do
    ntxs = 3000
    nsenders = 2
    assert :ok = Performance.SimplePerftest.start(ntxs, nsenders, %{destdir: destdir, block_every_ms: 3000})

    assert ["perf_result" <> _ = perf_result] = File.ls!(destdir)
    smoke_test_statistics(Path.join(destdir, perf_result), ntxs * nsenders)
  end

  defp smoke_test_statistics(path, expected_txs) do
    assert {:ok, stats} = Jason.decode(File.read!(path))

    txs_count =
      stats
      |> Enum.map(fn entry -> entry["txs"] end)
      |> Enum.sum()

    assert txs_count == expected_txs
  end

  defp smoke_test_profiling(path) do
    String.contains?(File.read!(path), "%% Analysis results:\n{")
  end
end

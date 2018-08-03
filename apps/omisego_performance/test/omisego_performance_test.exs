defmodule OmiseGO.PerformanceTest do
  use ExUnitFixtures
  use ExUnit.Case, async: false
  import ExUnit.CaptureIO

  use OmiseGO.API.LoggerExt

  @moduletag :integration

  deffixture destdir do
    {:ok, _} = Application.ensure_all_started(:briefly)

    {:ok, destdir} = Briefly.create(directory: true, prefix: "temp_results")

    destdir
  end

  @tag fixtures: [:destdir]
  test "Smoke test - run tests and see if they don't crash", %{destdir: destdir} do
    ntxs = 3000
    nsenders = 2
    assert :ok = OmiseGO.Performance.setup_and_run(ntxs, nsenders, %{destdir: destdir})

    assert ["perf_result" <> _ = perf_result] = File.ls!(destdir)
    smoke_test_statistics(Path.join(destdir, perf_result), ntxs * nsenders)
  end

  @tag fixtures: [:destdir]
  test "Smoke test - run tests and see if they don't crash - with profiling", %{destdir: destdir} do
    ntxs = 3
    nsenders = 2

    fprof_io =
      capture_io(fn -> assert :ok = OmiseGO.Performance.setup_and_run(3, 2, %{destdir: destdir, profile: true}) end)

    # TODO a warning is printed out in fprof_io - check it out and possibly test against that
    if fprof_io =~ "Warning", do: _ = Logger.warn(fn -> "fprof prints warnings during test" end)

    assert fprof_io =~ "Done!"

    assert ["perf_result" <> _, "perf_result" <> _] = result_files = File.ls!(destdir)

    prof_results = Enum.find(result_files, fn name -> String.contains?(name, "profiling") end)
    perf_results = Enum.find(result_files, fn name -> String.contains?(name, "stats") end)

    assert String.contains?(File.read!(Path.join(destdir, prof_results)), "%% Analysis results:\n{")

    smoke_test_statistics(Path.join(destdir, perf_results), ntxs * nsenders)
  end

  @tag fixtures: [:destdir]
  test "Smoke test - run tests and see if they don't crash - overiding block creation", %{destdir: destdir} do
    ntxs = 3000
    nsenders = 2
    assert :ok = OmiseGO.Performance.setup_and_run(3000, 2, %{destdir: destdir, block_every_ms: 3000})

    assert ["perf_result" <> _] = File.ls!(destdir)

    assert ["perf_result" <> _ = perf_result] = File.ls!(destdir)
    smoke_test_statistics(Path.join(destdir, perf_result), ntxs * nsenders)
  end

  defp smoke_test_statistics(path, expected_txs) do
    assert {:ok, stats} = Poison.decode(File.read!(path))

    txs_count =
      stats
      |> Enum.map(fn entry -> entry["txs"] end)
      |> Enum.sum()

    assert txs_count == expected_txs
  end
end

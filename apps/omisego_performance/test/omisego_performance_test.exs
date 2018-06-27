defmodule OmiseGO.PerformanceTest do
  use ExUnitFixtures
  use ExUnit.Case, async: false

  @moduletag :integration

  deffixture destdir do
    {:ok, _} = Application.ensure_all_started(:briefly)

    {:ok, destdir} = Briefly.create(directory: true, prefix: "temp_results")

    destdir
  end

  @tag fixtures: [:destdir]
  test "Smoke test - run tests and see if they don't crash", %{destdir: destdir} do
    assert :ok = OmiseGO.Performance.setup_and_run(3000, 2, %{destdir: destdir})

    assert ["perf_result" <> _ = perf_result] = File.ls!(destdir)
    smoke_test_statistics(Path.join(destdir, perf_result))
  end

  @tag fixtures: [:destdir]
  test "Smoke test - run tests and see if they don't crash - with profiling", %{destdir: destdir} do
    assert :ok = OmiseGO.Performance.setup_and_run(3, 2, %{destdir: destdir, profile: true})

    assert ["perf_result" <> _, "perf_result" <> _] = result_files = File.ls!(destdir)

    prof_results = Enum.find(result_files, fn name -> String.contains?(name, "profiling") end)

    assert String.contains?(File.read!(Path.join(destdir, prof_results)), "%% Analysis results:\n{")
  end

  @tag fixtures: [:destdir]
  test "Smoke test - run tests and see if they don't crash - overiding block creation", %{destdir: destdir} do
    assert :ok = OmiseGO.Performance.setup_and_run(3000, 2, %{destdir: destdir, block_every_ms: 1000})

    assert ["perf_result" <> _] = File.ls!(destdir)

    assert ["perf_result" <> _ = perf_result] = File.ls!(destdir)
    smoke_test_statistics(Path.join(destdir, perf_result))
  end

  defp smoke_test_statistics(path) do
    assert String.contains?(File.read!(path), "Performance statistics:")
  end
end

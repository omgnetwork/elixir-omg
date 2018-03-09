defmodule HonteD.Integration.PerformanceTest do
  @moduledoc """
  Integration test of the performance testing device.

  NOTE that this doesn't test performance. It tests the preformance test
  """

  use ExUnitFixtures
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  alias HonteD.Integration.Performance

  @moduletag :integration

  @moduletag timeout: :infinity

  @duration 3 # so that at least one block gets mined :)

  @nstreams 2
  @fill_in 2

  deffixture in_profiling_tempdir(homedir) do
    profiling_results_path = Path.join([homedir, "profiling_results"])
    File.mkdir_p!(profiling_results_path)
    current_dir = File.cwd!()
    File.cd!(profiling_results_path)

    on_exit fn ->
      File.cd!(current_dir)
    end
  end

  @tag fixtures: [:tendermint]
  test "performance test should run with fill in", %{} do
    result = Performance.run(@nstreams, @fill_in, @duration)

    result
    |> check_if_tm_bench_printed
  end

  @tag fixtures: [:tendermint, :in_profiling_tempdir]
  test "smoke test profilers", %{} do

    various_profilers = [%{profiling: :fprof},
                         %{profiling: :eep}, ]

    fn ->
      various_profilers
      |> Enum.map(&(Performance.run(0, 0, 1, &1))) # yes we want an empty test run for easiness - otherwise TM complains
      |> Enum.each(&check_if_tm_bench_printed/1)
    end
    |> capture_io()
    |> String.contains?("ACC") # just something that should be there (fprof) - smoke testing
    |> assert
  end

  defp check_if_tm_bench_printed(result) do
    result
    |> String.contains?("Txs/sec")
    |> assert
  end
end

defmodule HonteD.Integration.Performance.TMBench do
  @moduledoc """
  Handling of the tm_bench facility from tendermint/tools
  """

  alias HonteD.Integration

  @doc """
  Starts a tm-bench Porcelain process for `duration` to listen for events and collect metrics
  """
  def start_for(duration) do
    # start the benchmarking tool and capture the stdout
    tm_bench_proc = %Porcelain.Process{err: nil, out: tm_bench_out} = Porcelain.spawn_shell(
      "tm-bench -c 0 -T #{duration} localhost:46657",
      out: :stream,
    )
    :ok = wait_for_tm_bench_start(tm_bench_out)

    {tm_bench_proc, tm_bench_out}
  end

  defp wait_for_tm_bench_start(tm_bench_out) do
    Integration.wait_for_start(tm_bench_out, "Running ", 1000)
  end

  def finalize_output(tm_bench_out) do
    tm_bench_out
    |> Enum.to_list
    |> Enum.join
  end
end

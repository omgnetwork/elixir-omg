defmodule HonteD.PerftestScript do
  @moduledoc """
  Wrapper around HonteD.Integratoin.Performance to run commandline-like invocations of the performance test

  Usage examples:
  ```
  mix run --no-start -e 'HonteD.PerftestScript.setup_and_run(5, 0, 100)'
  mix run --no-start -e 'HonteD.PerftestScript.setup_and_run(5, 0, 100, %{profiling: :fprof})'
  mix run --no-start -e 'HonteD.PerftestScript.setup_and_run(5, 0, 100, %{homedir_size: true})'
  ```

  Available profilers: `:fprof`, `:eep`

  NOTE: keep this as thin as reasonably possible, this is not tested (excluded in coveralls.json)
  """

  alias HonteD.Integration

  @doc """
  Runs full HonteD node and runs perf test
  """
  def setup_and_run(nstreams, fill_in, duration, opts \\ %{}) do
    [:porcelain, :hackney]
    |> Enum.each(&Application.ensure_all_started/1)

    homedir = Integration.homedir()
    {:ok, _exit_fn_honted} = Integration.honted()
    {:ok, _exit_fn_tendermint} = Integration.tendermint(homedir)

    result = Integration.Performance.run(nstreams, fill_in, duration, opts)

    if opts[:homedir_size] do
      IO.puts("\n")
      %Porcelain.Result{err: nil, out: out} = Porcelain.shell("set -xe; du -sh #{homedir}")
      IO.puts("Disk used for homedir:\n#{out}\n")
    end

    # TODO: don't know why this is needed, should happen automatically on terminate. Does something bork at teardown?
    Temp.cleanup()

    IO.puts(result)
  end
end

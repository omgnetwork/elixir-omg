defmodule OmiseGO.PerfTest do
  @moduledoc """
  Tooling to run OmiseGO performance tests - orchestration and running tests
  """

  @doc """
  Assumes test suite setup is done earlier, before running this function.
  Foreach user runs n submit_transaction requests to the chain server. Requests are done sequencially.
  """
  def run(nrequests, nusers, opt \\ %{}) do
    IO.puts "OmiseGO PerfTest - users: #{nusers}, reqs: #{nrequests}."
    :ok
  end
end

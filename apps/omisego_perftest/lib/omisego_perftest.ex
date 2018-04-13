defmodule OmiseGO.PerfTest do
  @moduledoc """
  Tooling to run OmiseGO performance tests - orchestration and running tests
  """

  @block_num 1000

  @doc """
  Assumes test suite setup is done earlier, before running this function.
  Foreach user runs n submit_transaction requests to the chain server. Requests are done sequencially.
  """
  def run(nrequests, nusers, opt \\ %{}) do
    IO.puts "OmiseGO PerfTest - users: #{nusers}, reqs: #{nrequests}."

    # fire async current block checker
    CurrentBlockChecker.start_link()

    # init proces registry
    {:ok, _} = Registry.start_link(keys: :duplicate, name: OmiseGO.PerfTest.Registry)

    # fire async transaction senders
    1..nusers |> Enum.map(fn n -> SenderServer.start_link(nrequests) end)

    :ok
  end
end

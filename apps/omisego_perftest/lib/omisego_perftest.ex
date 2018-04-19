defmodule OmiseGO.PerfTest.Runner do
  @moduledoc """
  OmiseGO performance tests - orchestration and running tests
  """

  @init_blocknum 1000

  @doc """
  Assumes test suite setup is done earlier, before running this function.
  Foreach user runs n submit_transaction requests to the chain server. Requests are done sequencially.
  """
  @spec run(nrequests :: integer, nusers :: integer, opt :: map) :: :ok
  def run(nrequests, nusers, opt \\ %{}) do
    IO.puts "OmiseGO PerfTest - users: #{nusers}, reqs: #{nrequests}."

    # init proces registry
    {:ok, _} = Registry.start_link(keys: :duplicate, name: OmiseGO.PerfTest.Registry)

    # fire async transaction senders
    #TODO: Consider running senders in supervisor - but would they restore their state?
    1..nusers |> Enum.map(fn senderid -> SenderServer.start_link({senderid, nrequests, @init_blocknum}) end)

    # fire async current block checker
    CurrentBlockChecker.start_link()

    # Wait all senders do thier job, checker will stop when it happens and stops itself
    ref = Process.monitor(CurrentBlockChecker)
    receive do
      {:DOWN, ^ref, :process, _obj, reason} ->
        IO.puts "Stoping performance tests, reason: #{reason}"
    end

    :ok
  end
end

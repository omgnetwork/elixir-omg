defmodule LoadTest.Scenario.Dummy do
  use Chaperon.Scenario

  def run(session) do
    session |> log_info("run transction all...")
  end
end

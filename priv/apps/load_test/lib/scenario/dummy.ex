defmodule LoadTest.Scenario.Dummy do
  @moduledoc """
  A pure dummy scenerio as a initial ramp up
  """

  use Chaperon.Scenario

  def run(session) do
    session |> log_info("run transction all...")
  end
end

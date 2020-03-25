defmodule LoadTest.Runner.Smoke do
  @moduledoc """
  Load tests for watcher info
  """

  use Chaperon.LoadTest

  def scenarios,
    do: [
      {{1, LoadTest.Scenario.Smoke}, %{}}
    ]
end

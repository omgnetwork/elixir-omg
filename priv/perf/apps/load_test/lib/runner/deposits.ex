defmodule LoadTest.Runner.Deposits do
  use Chaperon.LoadTest

  def scenarios do
    [
      {{1, LoadTest.Scenario.Deposits}, %{}}
    ]
  end
end

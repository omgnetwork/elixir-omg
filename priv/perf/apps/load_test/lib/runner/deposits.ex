defmodule LoadTest.Runner.Deposits do
  @moduledoc """
  Deposits tests runner.
  """
  use Chaperon.LoadTest

  def scenarios do
    [
      {{1, LoadTest.Scenario.Deposits}, %{}}
    ]
  end
end

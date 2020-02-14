defmodule LoadTest.WatcherInfo do
  @moduledoc """
  Load tests for watcher info
  """

  use Chaperon.LoadTest

  def scenarios,
    do: [
      {{5, LoadTest.Scenario.Dummy},
       %{
         iterations: 2
       }}
    ]
end

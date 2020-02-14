defmodule LoadTest.WatcherInfo do
  use Chaperon.LoadTest

  def scenarios,
    do: [
      {{5, LoadTest.Scenario.Dummy},
       %{
         iterations: 2
       }}
    ]
end

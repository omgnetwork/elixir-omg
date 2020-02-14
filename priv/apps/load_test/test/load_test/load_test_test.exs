defmodule LoadTestTest do
  use ExUnit.Case
  doctest LoadTest

  test "dummy chaperon test" do
    Chaperon.run_load_test(LoadTest.WatcherInfo, print_results: false)
  end
end

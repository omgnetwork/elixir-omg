defmodule LoadTestTest do
  use ExUnit.Case
  doctest LoadTest

  test "smoke test" do
    Chaperon.run_load_test(LoadTest.Smoke, print_results: false)
  end
end

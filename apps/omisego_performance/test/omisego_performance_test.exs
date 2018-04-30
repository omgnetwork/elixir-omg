defmodule OmiseGO.PerformanceTest do
  use ExUnit.Case

  test "Smoke test - run tests and see if they don't crash" do
    result = OmiseGO.Performance.setup_and_run(3, 2)
    assert :ok = result
  end
end

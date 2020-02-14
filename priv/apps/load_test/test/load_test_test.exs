defmodule LoadTestTest do
  use ExUnit.Case
  doctest LoadTest

  test "greets the world" do
    assert LoadTest.hello() == :world
  end
end

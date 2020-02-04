defmodule EngineTest do
  use ExUnit.Case
  doctest Engine

  test "greets the world" do
    assert Engine.hello() == :world
  end
end

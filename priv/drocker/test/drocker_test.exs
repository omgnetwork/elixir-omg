defmodule DrockerTest do
  use ExUnit.Case
  doctest Drocker

  test "greets the world" do
    assert Drocker.hello() == :world
  end
end

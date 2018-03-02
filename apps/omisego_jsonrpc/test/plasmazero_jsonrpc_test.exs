defmodule OmiseGO.JSONRPCTest do
  use ExUnit.Case
  doctest OmiseGO.JSONRPC

  test "greets the world" do
    assert OmiseGO.JSONRPC.hello() == :world
  end
end

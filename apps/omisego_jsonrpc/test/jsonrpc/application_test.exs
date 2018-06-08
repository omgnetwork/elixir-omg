defmodule OmiseGO.JSONRPC.Application.Test do
  @moduledoc """
  Test the supervision tree stuff of the app
  """

  use ExUnitFixtures
  use ExUnit.Case, async: false

  test "OmiseGO json rpc should start fine" do
    assert {:ok, started} = Application.ensure_all_started(:omisego_jsonrpc)
    assert :omisego_jsonrpc in started
    for app <- started, do: :ok = Application.stop(app)
  end
end

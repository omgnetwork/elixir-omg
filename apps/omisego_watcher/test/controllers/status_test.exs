defmodule OmiseGOWatcherWeb.Controller.StatusTest do
  use ExUnitFixtures
  use ExUnit.Case, async: false

  alias OmiseGOWatcher.TestHelper, as: Test

  @tag fixtures: [:watcher_sandbox, :root_chain_contract_config]
  test "status endpoint provides expected information" do
    expected_keys = [
      "last_mined_child_block_number",
      "last_mined_child_block_timestamp",
      "last_validated_child_block_number",
      "syncing_status"
    ]

    status = Test.rest_call(:get, "/status")

    assert expected_keys == Map.keys(status)

    assert is_integer(Map.fetch!(status, "last_validated_child_block_number"))
    assert is_integer(Map.fetch!(status, "last_mined_child_block_number"))
    assert is_integer(Map.fetch!(status, "last_mined_child_block_timestamp"))
    assert is_atom(Map.fetch!(status, "syncing_status"))
  end
end

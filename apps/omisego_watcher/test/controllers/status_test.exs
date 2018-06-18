defmodule OmiseGOWatcherWeb.Controller.StatusTest do
  use ExUnitFixtures
  use ExUnit.Case, async: false

  alias OmiseGOWatcher.TestHelper, as: Test

  @tag fixtures: [:watcher_sandbox]
  test "status endpoint provides expected information" do
    status = Test.rest_call(:get, "/status")

    assert %{"last_child_block_height" => _,
      "last_mined_block_number" => _,
      "last_mined_block_timestamp" => _,
      "syncing_status" => _,
    } = status
  end
end

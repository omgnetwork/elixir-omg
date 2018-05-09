defmodule OmiseGOWatcher.ExitValidator.CoreTest do
  use ExUnitFixtures
  use ExUnit.Case, async: true

  alias OmiseGOWatcher.ExitValidator.Core

  deffixture initial_state(), do:
    %Core{last_exit_eth_height: 0, synced_eth_height: 10}

  @tag fixtures: [:initial_state]
  test "consecutive ranges of blocks are produced until there are no more finalized blocks",
    %{initial_state: state} do
  end
end

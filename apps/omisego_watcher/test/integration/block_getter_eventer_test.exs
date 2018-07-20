defmodule OmiseGOWatcher.BlockGetterEventerTest do
  use ExUnitFixtures
  use ExUnit.Case, async: false
  use OmiseGO.API.Fixtures
  use Plug.Test
  use Phoenix.ChannelTest

  alias OmiseGOWatcher.BlockGetter
  alias OmiseGOWatcher.Eventer

  @moduletag :integration

  @tag fixtures: [:watcher_sandbox]
  test "emit blockwithholding event" do
  end

  @tag fixtures: [:watcher_sandbox]
  test "detect potential block withholding and then cancel detecion" do
  end
end

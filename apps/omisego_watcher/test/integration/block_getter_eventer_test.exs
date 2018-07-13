defmodule OmiseGOWatcher.BlockGetterEventerTest do
  use ExUnitFixtures
  use ExUnit.Case, async: false
  use OmiseGO.API.Fixtures
  use Plug.Test
  use Phoenix.ChannelTest

  alias OmiseGOWatcher.Eventer
  alias OmiseGOWatcher.BlockGetter

  @moduletag :integration

  @tag fixtures: [:watcher_sandbox]
  test "test" do

  end

end

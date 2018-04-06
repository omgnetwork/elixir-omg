defmodule OmiseGOWatcherWeb.Controller.TransactionTest do
  use ExUnitFixtures
  use ExUnit.Case, async: false

  use Plug.Test

  alias OmiseGOWatcherWeb.Controller.Transaction

  @moduletag :watcher_tests

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(OmiseGOWatcher.Repo)
  end

end

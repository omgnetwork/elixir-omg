Code.load_file("../omisego_api/test/testlib/test_helper.ex")
Code.load_file("../omisego_eth/lib/eth/dev_helpers.ex")
ExUnit.configure(exclude: [watcher_tests: true])
ExUnitFixtures.start()
ExUnit.start()

if :omisego_watcher in Application.started_applications() do
  Ecto.Adapters.SQL.Sandbox.mode(OmiseGOWatcher.Repo, :manual)
end

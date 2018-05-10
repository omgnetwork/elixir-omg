ExUnit.configure(exclude: [watcher_tests: true])
ExUnitFixtures.start()
ExUnit.start()

if :omisego_watcher in Application.started_applications() do
  Ecto.Adapters.SQL.Sandbox.mode(OmiseGOWatcher.Repo, :manual)
end

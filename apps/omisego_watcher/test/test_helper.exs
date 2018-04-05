ExUnit.start()
ExUnit.configure(exclude: [watcher_tests: true])
if :omisego_watcher in Application.started_applications() do
  Ecto.Adapters.SQL.Sandbox.mode(OmiseGOWatcher.Repo, :manual)
end

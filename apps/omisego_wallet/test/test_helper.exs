ExUnit.start()
ExUnit.configure(exclude: [requires_postgres: true])
Ecto.Adapters.SQL.Sandbox.mode(OmisegoWallet.Repo, :manual)

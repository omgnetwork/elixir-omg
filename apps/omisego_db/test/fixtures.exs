defmodule OmiseGO.DB.Fixtures do
  @moduledoc """
  Contains fixtures for tests that require db
  """
  use ExUnitFixtures.FixtureModule

  deffixture db_initialized do
    {:ok, briefly} = Application.ensure_all_started(:briefly)
    db_path = Briefly.create!(directory: true)

    Application.put_env(:omisego_db, :leveldb_path, db_path, persistent: true)

    :ok = OmiseGO.DB.init()

    {:ok, started_apps} = Application.ensure_all_started(:omisego_db)

    on_exit(fn ->
      Application.put_env(:omisego_db, :leveldb_path, nil)

      (briefly ++ started_apps)
      |> Enum.reverse()
      |> Enum.map(fn app -> :ok = Application.stop(app) end)
    end)

    :ok
  end
end

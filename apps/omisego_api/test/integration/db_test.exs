defmodule OmiseGO.API.Integration.DBTest do

  use ExUnitFixtures
  use ExUnit.Case, async: false

  alias OmiseGO.DB

  deffixture db_path_config() do
    dir = Temp.mkdir!()

    Application.put_env(:omisego_db, :leveldb_path, dir, persistent: true)
    {:ok, started_apps} = Application.ensure_all_started(:omisego_db)

    on_exit fn ->
      Application.put_env(:omisego_db, :leveldb_path, nil)
      started_apps
        |> Enum.reverse()
        |> Enum.map(fn app -> :ok = Application.stop(app) end)
    end
    :ok
  end

  @tag fixtures: [:db_path_config]
  test "saves state in DB" do
    IO.inspect DB.utxos()
  end

end

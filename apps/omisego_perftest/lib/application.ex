defmodule OmiseGO.PerfTest do
  @moduledoc """

  """

  import Supervisor.Spec
  alias OmiseGO.PerfTest.Runner

  @doc """

  """
  def setup_and_run(nrequests, nusers, opt \\ %{}) do
    {:ok, started_apps} = testup()

    children = [
      supervisor(Phoenix.PubSub.PG2, [:eventer, []]),
      {OmiseGO.API.State, []},
      {OmiseGO.API.FreshBlocks, []},

    ]
    Supervisor.start_link(children, [strategy: :one_for_one])

    #Runner.run(nrequests, nusers, opt)

    #testdown(started_apps)
  end

  defp testup() do
    setup_leveldb()
  end

  defp testdown(started_apps) do
    started_apps |> Enum.reverse |> Enum.map(&Application.stop/1)
    Application.put_env(:omisego_db, :leveldb_path, nil)
  end

  defp setup_leveldb() do
    dbdir = "/tmp/perftest-#{:os.system_time(:millisecond)}"
    Application.put_env(:omisego_db, :leveldb_path, dbdir, persistent: true)

    {:ok, started_apps} = Application.ensure_all_started(:omisego_db)

    :ok = OmiseGO.DB.multi_update([{:put, :last_deposit_block_height, 0}])

    {:ok, started_apps}
  end
end

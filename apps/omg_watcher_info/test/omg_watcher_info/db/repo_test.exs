defmodule OMG.WatcherInfo.DB.RepoTest do
  use ExUnit.Case, async: false

  import Ecto.Query, only: [from: 2]

  import OMG.WatcherInfo.Factory

    # @doc "run only database in sandbox and endpoint to make request"
    # deffixture phoenix_ecto_sandbox(web_endpoint) do
    #   :ok = web_endpoint

    #   {:ok, pid} =
    #     Supervisor.start_link(
    #       [%{id: DB.Repo, start: {DB.Repo, :start_link, []}, type: :supervisor}],
    #       strategy: :one_for_one,
    #       name: WatcherInfo.Supervisor
    #     )

    #   :ok = SQL.Sandbox.checkout(DB.Repo)
    #   # setup and body test are performed in one process, `on_exit` is performed in another
    #   on_exit(fn ->
    #     WatcherInfoHelper.wait_for_process(pid)
    #     :ok
    #   end)
    # end

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(OMG.WatcherInfo.DB.Repo)
  end

  # test "insert_all_chunked adds inserted_at and updated_at timestamps correctly" do
  #   blknum = 5432

  #   block = %{blknum: blknum, eth_height: 1, hash: "#1000", timestamp: 1}

  #   DB.Repo.insert_all_chunked(OMG.Watcher.DB.Block, [block])

  #   db_block = DB.Repo.one(from(block in OMG.Watcher.DB.Block, where: block.blknum == ^blknum))

  #   # on insert inserted_at and updated_at should be approximately equal or updated_at will be greater
  #   assert DateTime.compare(db_block.inserted_at, db_block.updated_at) == :lt ||
  #            DateTime.compare(db_block.inserted_at, db_block.updated_at) == :eq

  #   DB.Repo.delete(db_block)
  # end

  test "factory works" do
    block = insert(:block)

    IO.inspect(block, label: "block")
  end
end

defmodule OMG.Watcher.DB.RepoTest do
  use ExUnitFixtures
  use ExUnit.Case, async: false
  use OMG.Fixtures

  import Ecto.Query, only: [from: 2]

  alias OMG.Watcher.DB

  @tag fixtures: [:phoenix_ecto_sandbox]
  test "insert_all_chunked adds inserted_at and updated_at timestamps correctly" do
    blknum = 5432

    block = %{blknum: blknum, eth_height: 1, hash: "#1000", timestamp: 1}

    DB.Repo.insert_all_chunked(OMG.Watcher.DB.Block, [block])

    db_block = DB.Repo.one(from(block in OMG.Watcher.DB.Block, where: block.blknum == ^blknum))

    # on insert inserted_at and updated_at should be approximately equal or updated_at will be greater
    assert DateTime.compare(db_block.inserted_at, db_block.updated_at) == :lt ||
             DateTime.compare(db_block.inserted_at, db_block.updated_at) == :eq

    DB.Repo.delete(db_block)
  end
end

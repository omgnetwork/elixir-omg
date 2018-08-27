defmodule OMG.Watcher.Repo.Migrations.CreateCheckpointTable do
  use Ecto.Migration

  def change do
    create table(:checkpoints, primary_key: false) do
      add :blknum, :bigint, primary_key: true
      add :hash, :binary, null: false
      add :eth_height, :bigint, null: false
    end

    create unique_index(:checkpoints, [:hash])
  end
end

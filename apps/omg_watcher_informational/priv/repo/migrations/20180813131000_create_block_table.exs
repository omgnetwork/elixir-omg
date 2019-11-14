defmodule OMG.WatcherInformational.Repo.Migrations.CreateBlockTable do
  use Ecto.Migration

  def change do
    create table(:blocks, primary_key: false) do
      add :blknum, :bigint, null: false, primary_key: true
      add :hash, :binary, null: false
      add :timestamp, :integer, null: false
      add :eth_height, :bigint, null: false
    end
  end
end

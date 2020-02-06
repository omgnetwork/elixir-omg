defmodule OMG.WatcherInfo.Repo.Migrations.CreateEtheventTable do
  use Ecto.Migration

  def change() do
    create table(:ethevents, primary_key: false) do
      add :hash, :binary, primary_key: true
      add :blknum, :bigint
      add :txindex, :integer
      add :event_type, :string, size: 124, null: false
    end
  end
end

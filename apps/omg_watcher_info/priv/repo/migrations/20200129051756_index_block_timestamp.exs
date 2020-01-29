defmodule OMG.WatcherInfo.DB.Repo.Migrations.IndexBlockTimestamp do
  use Ecto.Migration

  def change do
    create(index(:blocks, [:owner]))
  end
end

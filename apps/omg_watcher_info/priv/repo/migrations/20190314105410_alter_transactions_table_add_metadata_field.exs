defmodule OMG.WatcherInfo.DB.Repo.Migrations.AlterTransactionsTableAddMetadataField do
  use Ecto.Migration

  def change() do
    alter table(:transactions) do
      add(:metadata, :binary)
    end
  end
end

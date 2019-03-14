defmodule OMG.Watcher.DB.Repo.Migrations.AlterTransactionsTableAddMetadataField do
  use Ecto.Migration

  def change do
    alter table(:transactions) do
      add(:metadata, :binary)
    end

    create index :transactions, :metadata
  end
end

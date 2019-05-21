defmodule OMG.Watcher.DB.Repo.Migrations.AlterTransactionsTableAddPartialIndex do
  use Ecto.Migration

  def change do
    create index(:transactions, [:metadata], where: "metadata IS NOT NULL")
  end
end

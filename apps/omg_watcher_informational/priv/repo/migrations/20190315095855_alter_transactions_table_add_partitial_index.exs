defmodule OMG.WatcherInformational.DB.Repo.Migrations.AlterTransactionsTableAddPartialIndex do
  use Ecto.Migration

  def up do
    execute("CREATE INDEX transactions_metadata_index ON transactions(metadata) WHERE metadata IS NOT NULL")
  end

  def down do
    execute("DROP INDEX transactions_metadata_index")
  end
end

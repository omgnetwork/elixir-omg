defmodule OMG.Watcher.DB.Repo.Migrations.RelaxTimestampNotNullConstraintsOnTxoutputsTable do
  use Ecto.Migration

  def change do
    alter table(:txoutputs) do
      modify :inserted_at, :utc_datetime, default: fragment("now() at time zone 'utc'"), null: true
      modify :updated_at, :utc_datetime, default: fragment("now() at time zone 'utc'"), null: true
    end
  end
end

defmodule OMG.Watcher.Repo.Migrations.AddAndFixTimestamps do
  use Ecto.Migration

  # this is a non-backward compatible change as the the `transactions.sent_at` column
  # is being removed, so only an `up()` function is defined

  def up() do
    Enum.each(["ethevents", "txoutputs", "ethevents_txoutputs"], fn table_name ->
      # backfill tables that may have null values for `inserted_at` and `updated_at` before adding NOT NULL constraint
      backfill_null_timestamps(table_name)

      update_timestamps_ddl(table_name)
    end)

    alter table(:transactions) do
      remove(:sent_at)

      timestamps([type: :timestamptz, default: fragment("('epoch'::TIMESTAMPTZ AT TIME ZONE 'UTC')")])
    end

    alter table(:blocks) do
      timestamps([type: :timestamptz, default: fragment("('epoch'::TIMESTAMPTZ AT TIME ZONE 'UTC')")])
    end
  end

  defp backfill_null_timestamps(table_name) do
    execute("UPDATE #{table_name} SET inserted_at=('epoch'::TIMESTAMPTZ AT TIME ZONE 'UTC'), updated_at=('epoch'::TIMESTAMPTZ AT TIME ZONE 'UTC') WHERE inserted_at IS NULL AND updated_at IS NULL")
  end

  defp update_timestamps_ddl(table_name) do
    # change column type. this must be done before column default can be set
    execute("ALTER TABLE #{table_name} ALTER COLUMN inserted_at TYPE TIMESTAMPTZ USING inserted_at AT TIME ZONE 'UTC'")
    execute("ALTER TABLE #{table_name} ALTER COLUMN updated_at TYPE TIMESTAMPTZ USING updated_at AT TIME ZONE 'UTC'")

    # add column default value and not null constraint
    execute("ALTER TABLE #{table_name} ALTER COLUMN inserted_at SET DEFAULT ('epoch'::TIMESTAMPTZ AT TIME ZONE 'UTC'), ALTER COLUMN inserted_at SET NOT NULL")
    execute("ALTER TABLE #{table_name} ALTER COLUMN updated_at SET DEFAULT ('epoch'::TIMESTAMPTZ AT TIME ZONE 'UTC'), ALTER COLUMN updated_at SET NOT NULL")
  end
end

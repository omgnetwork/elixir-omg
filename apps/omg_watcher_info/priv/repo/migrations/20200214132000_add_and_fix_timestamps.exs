defmodule OMG.Watcher.Repo.Migrations.AddAndFixTimestamps do
  use Ecto.Migration

  # this is a non-backward compatible change as the the `transactions.sent_at` column
  # is being removed, so only an `up()` function is defined

  def up() do
    execute("ALTER TABLE ethevents ALTER COLUMN inserted_at TYPE TIMESTAMPTZ USING inserted_at AT TIME ZONE 'UTC'")
    execute("ALTER TABLE ethevents ALTER COLUMN updated_at TYPE TIMESTAMPTZ USING updated_at AT TIME ZONE 'UTC'")
    execute("UPDATE ethevents SET inserted_at=('epoch'::TIMESTAMPTZ AT TIME ZONE 'UTC'), updated_at=('epoch'::TIMESTAMPTZ AT TIME ZONE 'UTC') WHERE inserted_at IS NULL AND updated_at IS NULL")
    execute("ALTER TABLE ethevents ALTER COLUMN inserted_at SET DEFAULT ('epoch'::TIMESTAMPTZ AT TIME ZONE 'UTC'), ALTER COLUMN inserted_at SET NOT NULL;")
    execute("ALTER TABLE ethevents ALTER COLUMN updated_at SET DEFAULT ('epoch'::TIMESTAMPTZ AT TIME ZONE 'UTC'), ALTER COLUMN updated_at SET NOT NULL;")
    execute("ALTER TABLE txoutputs ALTER COLUMN inserted_at TYPE TIMESTAMPTZ USING inserted_at AT TIME ZONE 'UTC'")
    execute("ALTER TABLE txoutputs ALTER COLUMN updated_at TYPE TIMESTAMPTZ USING updated_at AT TIME ZONE 'UTC'")
    execute("UPDATE txoutputs SET inserted_at=('epoch'::TIMESTAMPTZ AT TIME ZONE 'UTC'), updated_at=('epoch'::TIMESTAMPTZ AT TIME ZONE 'UTC') WHERE inserted_at IS NULL AND updated_at IS NULL")
    execute("ALTER TABLE txoutputs ALTER COLUMN inserted_at SET DEFAULT ('epoch'::TIMESTAMPTZ AT TIME ZONE 'UTC'), ALTER COLUMN inserted_at SET NOT NULL;")
    execute("ALTER TABLE txoutputs ALTER COLUMN updated_at SET DEFAULT ('epoch'::TIMESTAMPTZ AT TIME ZONE 'UTC'), ALTER COLUMN updated_at SET NOT NULL;")
    execute("ALTER TABLE ethevents_txoutputs ALTER COLUMN inserted_at TYPE TIMESTAMPTZ USING inserted_at AT TIME ZONE 'UTC'")
    execute("ALTER TABLE ethevents_txoutputs ALTER COLUMN updated_at TYPE TIMESTAMPTZ USING updated_at AT TIME ZONE 'UTC'")
    execute("UPDATE ethevents_txoutputs SET inserted_at=('epoch'::TIMESTAMPTZ AT TIME ZONE 'UTC'), updated_at=('epoch'::TIMESTAMPTZ AT TIME ZONE 'UTC') WHERE inserted_at IS NULL AND updated_at IS NULL")
    execute("ALTER TABLE ethevents_txoutputs ALTER COLUMN inserted_at SET DEFAULT ('epoch'::TIMESTAMPTZ AT TIME ZONE 'UTC'), ALTER COLUMN inserted_at SET NOT NULL")
    execute("ALTER TABLE ethevents_txoutputs ALTER COLUMN updated_at SET DEFAULT ('epoch'::TIMESTAMPTZ AT TIME ZONE 'UTC'), ALTER COLUMN updated_at SET NOT NULL")

    alter table(:transactions) do
      remove(:sent_at)

      timestamps([type: :timestamptz, default: fragment("('epoch'::TIMESTAMPTZ AT TIME ZONE 'UTC')")])
    end

    alter table(:blocks) do
      timestamps([type: :timestamptz, default: fragment("('epoch'::TIMESTAMPTZ AT TIME ZONE 'UTC')")])
    end
  end
end

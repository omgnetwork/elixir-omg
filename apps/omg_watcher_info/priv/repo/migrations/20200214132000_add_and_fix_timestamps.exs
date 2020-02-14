defmodule OMG.Watcher.Repo.Migrations.AddAndFixTimestamps do
  use Ecto.Migration

  # this is a non-backward compatible change as the the transactions.sent_at column
  # is being removed, so only an `up()` function is defined

  def up() do
    # the timestamp columns for this table were originally added with the wrong precision,
    # so we update it here to microsecond precision
    alter table(:ethevents) do
      modify(:inserted_at, :utc_datetime_usec)
      modify(:updated_at, :utc_datetime_usec)
    end

    # the timestamp columns for this table were originally added with the wrong precision,
    # so we update it here to microsecond precision
    alter table(:txoutputs) do
      modify(:inserted_at, :utc_datetime_usec)
      modify(:updated_at, :utc_datetime_usec)
    end

    # the timestamp columns for this table were originally added with the wrong precision,
    # so we update it here to microsecond precision
    alter table(:ethevents_txoutputs) do
      modify(:inserted_at, :utc_datetime_usec)
      modify(:updated_at, :utc_datetime_usec)
    end

    alter table(:transactions) do
      remove(:sent_at)

      timestamps([type: :utc_datetime_usec, default: "1970-01-01T00:00:00Z"])
    end

    alter table(:blocks) do
      timestamps([type: :utc_datetime_usec, default: "1970-01-01T00:00:00Z"])
    end
  end
end

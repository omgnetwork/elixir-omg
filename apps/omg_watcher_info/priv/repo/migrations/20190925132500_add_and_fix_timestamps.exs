defmodule OMG.Watcher.Repo.Migrations.AddAndFixTimestamps do
  use Ecto.Migration

  def change do
    # the timestamp columns for this table were oringally added with the wrong precision,
    # so we update it here to microsecond precision
    alter table(:ethevents) do
      remove(:inserted_at)
      remove(:updated_at)
    end

    alter table(:ethevents) do
      timestamps([type: :utc_datetime_usec, default: "1970-01-01T00:00:00Z"])
    end

    # the timestamp columns for this table were oringally added with the wrong precision,
    # so we update it here to microsecond precision
    alter table(:txoutputs) do
      remove(:inserted_at)
      remove(:updated_at)
    end

    alter table(:txoutputs) do
      timestamps([type: :utc_datetime_usec, default: "1970-01-01T00:00:00Z"])
    end

    alter table(:ethevents_txoutputs) do
      modify(:inserted_at, :utc_datetime_usec, default: "1970-01-01T00:00:00Z")
      modify(:updated_at, :utc_datetime_usec, default: "1970-01-01T00:00:00Z")
    end

    alter table(:transactions) do
      remove(:sent_at)
      
      modify(:blknum, :bigint, null: false)

      timestamps([type: :utc_datetime_usec, default: "1970-01-01T00:00:00Z"])
    end

    alter table(:blocks) do
      timestamps([type: :utc_datetime_usec, default: "1970-01-01T00:00:00Z"])
    end
  end
end

defmodule OMG.Watcher.Repo.Migrations.AddAndFixTimestamps do
  use Ecto.Migration

  def change do
    # the timestamp columns for this table were oringally added with the wrong precision,
    # so we update it here to microsecond precision
    alter table(:ethevents) do
      remove :inserted_at
      remove :updated_at
    end

    alter table(:ethevents) do
      timestamps([default: "1970-01-01T00:00:00Z"])
    end

    # the timestamp columns for this table were oringally added with the wrong precision,
    # so we update it here to microsecond precision
    alter table(:txoutputs) do
      remove :inserted_at
      remove :updated_at
    end

    alter table(:txoutputs) do
      timestamps([default: "1970-01-01T00:00:00Z"])
    end

    # timestamps removed from join table ethevents_txoutputs because ecto has poor support for join tables
    # with extra columns. i'm not sure it adds much anyway
    alter table(:ethevents_txoutputs) do
      remove :inserted_at
      remove :updated_at
    end

    alter table(:transactions) do
      timestamps([default: "1970-01-01T00:00:00Z"])
    end

    alter table(:blocks) do
      timestamps([default: "1970-01-01T00:00:00Z"])
    end
  end
end

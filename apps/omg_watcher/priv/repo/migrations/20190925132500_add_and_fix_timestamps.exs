defmodule OMG.Watcher.Repo.Migrations.AddAndFixTimestamps do
  use Ecto.Migration

  def change do
    alter table(:ethevents) do
      remove :inserted_at
      remove :updated_at
    end

    alter table(:ethevents) do
      timestamps([default: "1970-01-01T00:00:00Z"])
    end

    alter table(:txoutputs) do
      remove :inserted_at
      remove :updated_at
    end

    alter table(:txoutputs) do
      timestamps([default: "1970-01-01T00:00:00Z"])
    end

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

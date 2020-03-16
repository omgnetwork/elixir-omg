defmodule OMG.WatcherInfo.Repo.Migrations.SetInsertedAtUpdatedAtToEpoch do
  use Ecto.Migration

  def change() do
    execute("UPDATE txoutputs SET inserted_at = 'epoch' at time zone 'utc';")
    execute("UPDATE txoutputs SET updated_at = 'epoch' at time zone 'utc';")
    execute("ALTER TABLE txoutputs ALTER COLUMN inserted_at SET NOT NULL;")
    execute("ALTER TABLE txoutputs ALTER COLUMN updated_at SET NOT NULL;")
  end
end

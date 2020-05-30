defmodule OMG.WatcherInfo.DB.Repo.Migrations.CreatePendingBlockTable do
  use Ecto.Migration

  def change() do
    create table(:pending_blocks, primary_key: false) do
      add :blknum, :bigint, null: false, primary_key: true
      add :data, :binary, null: false
      add :status, :string, null: false
      add :retry_count, :integer, null: false

      timestamps([type: :timestamptz, default: fragment("('epoch'::TIMESTAMPTZ AT TIME ZONE 'UTC')")])
    end
  end
end

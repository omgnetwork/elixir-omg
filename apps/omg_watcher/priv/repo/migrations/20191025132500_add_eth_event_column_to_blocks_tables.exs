defmodule OMG.Watcher.Repo.Migrations.AddEthEventColumnToBlocksTable do
  use Ecto.Migration

  def change do
    alter table(:blocks) do
      add(:root_chain_txhash_event,
          references(:ethevents, column: :root_chain_txhash_event, type: :binary, on_delete: :restrict))
    end

    flush()

    # backfill pre-existing blocks
    execute("UPDATE blocks SET root_chain_txhash_event = '\\000';")

    execute("ALTER TABLE blocks ALTER COLUMN root_chain_txhash_event SET NOT NULL;")
  end
end



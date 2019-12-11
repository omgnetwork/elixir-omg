
defmodule OMG.WatcherInfo.DB.Repo.Migrations.AlterTxOutputsTableAddRootchainTxnHashDepositAndExitColumns do
  use Ecto.Migration

  # non-backward compatible migration, thus cannot use `change/0`

  def up do
    drop constraint(:txoutputs, "txoutputs_creating_deposit_fkey")
    drop constraint(:txoutputs, "txoutputs_spending_exit_fkey")
    drop constraint(:ethevents, "ethevents_pkey")

    flush()

    # drop ethevents table and rebuild it as this table is currently unused for all practical purposes.
    # when getting utxos we filter on txoutputs.creating_deposit is nil and txoutputs.spending is nil and
    # never query/join with the ethevents table.
    # dropping is easiest here because we are altering what the primary key is

    drop table(:ethevents)

    create table(:ethevents, primary_key: false) do
      add(:root_chain_txhash, :binary, primary_key: true)
      add(:log_index, :int, primary_key: true)

      add(:event_type, :string, size: 124)

      add(:root_chain_txhash_event, :binary)

      timestamps([type: :utc_datetime])
    end

    create index(:ethevents, :root_chain_txhash)
    create index(:ethevents, :log_index)
    create unique_index(:ethevents, :root_chain_txhash_event)

    # how to do this in ecto correctly? do it manually
    execute("ALTER TABLE ethevents ALTER COLUMN inserted_at SET DEFAULT (now() at time zone 'utc');")
    execute("ALTER TABLE ethevents ALTER COLUMN updated_at SET DEFAULT (now() at time zone 'utc');")

    alter table(:txoutputs) do
      add(:child_chain_utxohash, :binary)
    end

    create unique_index(:txoutputs, :child_chain_utxohash)

    flush()

    # backfill child_chain_utxohash with values from either creating_deposit or spending_exit
    execute """
      UPDATE txoutputs as t
        SET child_chain_utxohash =
          (SELECT
             CASE WHEN creating_deposit IS NULL THEN spending_exit
                  WHEN spending_exit IS NULL THEN creating_deposit
                  ELSE creating_deposit || spending_exit
             END AS txhash
           FROM txoutputs as t_inner
           WHERE t.creating_deposit = t_inner.creating_deposit OR t.spending_exit = t_inner.spending_exit);
    """

    alter table(:txoutputs) do
      remove(:creating_deposit)
      remove(:spending_exit)

      timestamps(type: :utc_datetime, default: fragment("(now() at time zone 'utc')"), null: true)
    end

    create table(:ethevents_txoutputs, primary_key: false) do
      add(:root_chain_txhash_event,
        references(:ethevents, column: :root_chain_txhash_event, type: :binary, on_delete: :restrict),
                   primary_key: true)
      add(:child_chain_utxohash, references(:txoutputs, column: :child_chain_utxohash, type: :binary,
          on_delete: :restrict), primary_key: true)

      timestamps([type: :utc_datetime])
    end

    # how to do this in ecto correctly? do it manually
    execute("ALTER TABLE ethevents_txoutputs ALTER COLUMN inserted_at SET DEFAULT (now() at time zone 'utc');")
    execute("ALTER TABLE ethevents_txoutputs ALTER COLUMN updated_at SET DEFAULT (now() at time zone 'utc');")

    create index(:ethevents_txoutputs, :root_chain_txhash_event)
    create index(:ethevents_txoutputs, :child_chain_utxohash)
  end

  def down do
    # non-backward compatible migration, thus cannot use `change/0`
    # no-op
  end
end

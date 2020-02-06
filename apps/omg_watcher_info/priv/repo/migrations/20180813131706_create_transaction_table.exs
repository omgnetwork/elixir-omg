defmodule OMG.WatcherInfo.Repo.Migrations.CreateTransactionTable do
  use Ecto.Migration

  def change() do
    create table(:transactions, primary_key: false) do
      add :txhash, :binary, primary_key: true
      add :txindex, :integer, null: false
      add :txbytes, :binary, null: false
      add :sent_at, :timestamp
      add :blknum, references(:blocks, column: :blknum, type: :bigint)
    end

    # TODO: this will work as long as there will be not nulls here
    create unique_index(:transactions, [:blknum, :txindex], name: :unq_transaction_blknum_txindex)
  end
end

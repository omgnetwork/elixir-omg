defmodule OMG.Watcher.Repo.Migrations.CreateSpendsTable do
  use Ecto.Migration

  def change do
    create table(:spends, primary_key: false) do
      add :blknum, :bigint, null: false, primary_key: true
      add :txindex, :integer, null: false, primary_key: true
      add :oindex, :integer, null: false, primary_key: true
      add :spending_txhash,  :binary
      add :spending_tx_oindex, :integer
    end
  end
end

defmodule OMG.Watcher.Repo.Migrations.CreateTxoutputTable do
  use Ecto.Migration

  def change do
    create table(:txoutputs, primary_key: true) do
      add :creating_txhash, references(:transactions, column: :txhash, type: :binary)
      add :creating_deposit, references(:ethevents, column: :hash, type: :binary)
      add :creating_tx_oindex, :integer, default: 0, null: false
      add :spending_txhash, references(:transactions, column: :txhash, type: :binary)
      add :spending_exit, references(:ethevents, column: :hash, type: :binary)
      add :spending_tx_oindex, :integer
      add :owner, :binary, null: false
      add :amount, :decimal, precision: 81, scale: 0, null: false
      add :currency, :binary, null: false
      add :proof, :binary
    end
  end
end

defmodule OmiseGOWatcher.Repo.Migrations.CreateUtxo do
  use Ecto.Migration

  def change do
    create table(:utxos) do
      add :address, :binary, null: false
      add :currency, :binary, null: false
      add :amount, :integer, null: false
      add :blknum, :integer, null: false
      add :oindex, :integer, null: false
      add :txbytes, :binary, null: false
      add :txindex, :integer, null: false
    end
  end

end

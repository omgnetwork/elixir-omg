defmodule OmiseGOWatcher.Repo.Migrations.CreateUtxo do
  use Ecto.Migration

  def change do
    create table(:utxos) do
      add :address, :string
      add :amount, :integer
      add :blknum, :integer
      add :oindex, :integer
      add :txbytes, :text
      add :txindex, :integer
    end
  end

end

defmodule Engine.Repo.Migrations.CreateUtxos do
  use Ecto.Migration

  def change do
    create table(:utxos) do
      # UTXO position information
      add :blknum, :integer, default: 0
      add :txindex, :integer, default: 0
      add :oindex, :integer, default: 0

      # UTXO output information
      add :output_type, :integer, default: 1
      add :owner, :string
      add :currency, :string
      add :amount, :integer, null: false, default: 0
    end
  end
end

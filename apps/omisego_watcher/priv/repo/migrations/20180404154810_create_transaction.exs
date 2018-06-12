defmodule OmiseGOWatcher.Repo.Migrations.CreateTransaction do
  use Ecto.Migration

  def change do
    create table(:transactions, primary_key: false) do
      add :txid, :binary, primary_key: true

      add :blknum1, :integer, null: false
      add :txindex1, :integer, null: false
      add :oindex1, :integer, null: false

      add :blknum2, :integer, null: false
      add :txindex2, :integer, null: false
      add :oindex2, :integer, null: false

      add :cur12, :string, null: false

      add :newowner1, :string, null: false
      add :amount1, :integer, null: false

      add :newowner2, :string, null: false
      add :amount2, :integer, null: false

      add :fee, :integer, null: false

      add :txblknum, :integer, null: false
      add :txindex, :integer, null: false
    end

  end
end

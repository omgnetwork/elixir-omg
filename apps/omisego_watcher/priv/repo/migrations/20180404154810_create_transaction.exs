defmodule OmiseGOWatcher.Repo.Migrations.CreateTransaction do
  use Ecto.Migration

  def change do
    create table(:transactions, primary_key: false) do
      add :txid, :binary, primary_key: true

      add :blknum1, :integer
      add :txindex1, :integer
      add :oindex1, :integer

      add :blknum2, :integer
      add :txindex2, :integer
      add :oindex2, :integer

      add :newowner1, :string
      add :amount1, :integer

      add :newowner2, :string
      add :amount2, :integer

      add :fee, :integer

      add :txblknum, :integer
      add :txindex, :integer
    end
  end
end

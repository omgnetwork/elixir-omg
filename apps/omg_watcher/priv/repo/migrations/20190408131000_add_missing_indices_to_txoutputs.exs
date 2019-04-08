defmodule OMG.Watcher.Repo.Migrations.AddMissingIndicesToTxOuputs do
  use Ecto.Migration

  def change do
    create index(:txoutputs, [:creating_txhash])
    create index(:txoutputs, [:creating_deposit])
    create index(:txoutputs, [:spending_txhash])
    create index(:txoutputs, [:spending_exit])
    create index(:txoutputs, [:owner])
  end
end

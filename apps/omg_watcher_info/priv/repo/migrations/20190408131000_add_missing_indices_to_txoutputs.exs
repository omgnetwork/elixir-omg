defmodule OMG.WatcherInfo.Repo.Migrations.AddMissingIndicesToTxOuputs do
  use Ecto.Migration

  def change do
    create index(:txoutputs, [:creating_txhash, :spending_txhash])
    create index(:txoutputs, [:creating_deposit])
    create index(:txoutputs, [:spending_txhash])
    create index(:txoutputs, [:spending_exit], where: "spending_exit IS NOT NULL")
    create index(:txoutputs, [:owner])
  end
end

defmodule OMG.WatcherInfo.DB.Repo.Migrations.AddEthHeightToEthEvents do
  use Ecto.Migration

  def up() do
    alter table(:ethevents) do
      add(:eth_height, :integer)
    end
  end
end

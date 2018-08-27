defmodule OMG.Watcher.Repo.Migrations.CreateAccountTable do
  use Ecto.Migration

  def change do
    create table(:accounts, primary_key: false) do
      add :address, :binary, primary_key: true
    end
  end
end

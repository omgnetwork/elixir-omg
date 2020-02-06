defmodule Engine.Repo.Migrations.CreateTransactions do
  use Ecto.Migration

  def change do
    create table(:transactions) do
      add :tx_type, :integer, default: 1
      add :tx_data, :integer, default: 0
      add :metadata, :binary

      add :block, references(:blocks)

      timestamps()
    end

    create index(:transactions, [:block])
  end
end

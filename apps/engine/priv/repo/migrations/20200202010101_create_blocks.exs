defmodule Engine.Repo.Migrations.CreateBlocks do
  use Ecto.Migration

  def change do
    create table(:blocks) do
      add :hash, :binary
      add :number, :integer

      timestamps()
    end

    create unique_index(:blocks, [:number])
  end
end

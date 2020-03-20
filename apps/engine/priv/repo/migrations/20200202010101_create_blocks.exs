defmodule Engine.Repo.Migrations.CreateBlocks do
  use Ecto.Migration

  def change do
    create table(:blocks) do
      add :hash, :binary
      add :number, :integer
      add :status, :string

      timestamps(type: :utc_datetime)
    end

    create unique_index(:blocks, [:number])
    create unique_index(:blocks, [:status])
  end
end

defmodule Front.Repo.Migrations.CreateTestRuns do
  use Ecto.Migration

  def change do
    create table(:test_runs) do
      add(:key, :string, null: false)
      add(:status, :string, null: false)
      add(:data, :map)

      timestamps(type: :timestamptz)
    end

    create index(:test_runs, [:key])
  end
end

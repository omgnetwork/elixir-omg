defmodule Front.Repo.TestRun do
  use Ecto.Schema

  alias Ecto.Changeset
  alias Front.Repo

  @type t :: %__MODULE__{
          id: non_neg_integer(),
          key: String.t(),
          status: String.t(),
          data: map(),
          updated_at: DateTime.t(),
          inserted_at: DateTime.t()
        }

  @required_fields [:key, :status]
  @optional_fields [:data]
  @statuses ["running", "finished"]

  schema "test_runs" do
    field(:key, :string)
    field(:status, :string)
    field(:data, :map)

    timestamps(type: :utc_datetime)
  end

  def create!(key) do
    %__MODULE__{}
    |> changeset(%{key: key, status: "running"})
    |> Repo.insert!()
  end

  def update!(struct, params) do
    struct
    |> changeset(params)
    |> Repo.update!()
  end

  defp changeset(test_run, params) do
    test_run
    |> Changeset.cast(params, @required_fields ++ @optional_fields)
    |> Changeset.validate_required(@required_fields)
    |> Changeset.validate_inclusion(:status, @statuses)
  end
end

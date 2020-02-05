defmodule Engine.Block do
  @moduledoc """
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "blocks" do
    field(:hash, :binary)
    field(:number, :integer)

    has_many(:transactions, Engine.Transaction)
  end
end

defmodule Engine.Block do
  @moduledoc """
  """

  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query, only: [from: 2]

  schema "blocks" do
    field(:hash, :binary)
    field(:number, :integer)

    has_many(:transactions, Engine.Transaction)

    timestamps(type: :utc_datetime)
  end

  @doc """
  Forms a pending block record based on the existing pending transactions.
  """
  def form_block() do
    query = from(t in Engine.Transaction, where: is_nil(t.block_id), limit: 25)
    result = Engine.Repo.all(query)
  end
end

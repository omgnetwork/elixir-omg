defmodule OmiseGOWatcher.TransactionDB do
  @moduledoc """
  Ecto Schema representing TransactionDB.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @field_names [
    :blknum1,
    :txindex1,
    :oindex1,
    :blknum2,
    :txindex2,
    :oindex2,
    :newowner1,
    :amount1,
    :newowner2,
    :amount2,
    :fee,
    :txblknum,
    :txindex
  ]
  def field_names, do: @field_names

  derive {Poison.Encoder, except: [:__meta__]}
  schema "transactions" do
    field(:blknum1, :integer)
    field(:txindex1, :integer)
    field(:oindex1, :integer)

    field(:blknum2, :integer)
    field(:txindex2, :integer)
    field(:oindex2, :integer)

    field(:newowner1, :string)
    field(:amount1, :integer)

    field(:newowner2, :string)
    field(:amount2, :integer)

    field(:fee, :integer)

    field(:txblknum, :integer)
    field(:txindex, :integer)
  end

  def changeset(transaction_db, attrs) do
    transaction_db
    |> cast(attrs, @field_names)
    |> validate_required(@field_names)
  end
end

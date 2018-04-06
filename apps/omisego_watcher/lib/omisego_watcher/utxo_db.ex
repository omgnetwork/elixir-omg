defmodule OmiseGOWatcher.UtxoDB do
  @moduledoc"""
  Template for creating (mix ecto.migrate) and using tables (database).
  """
  use Ecto.Schema
  import Ecto.Changeset

  @field_names [:address, :amount, :blknum, :oindex, :txbytes, :txindex]
  def field_names, do: @field_names

  schema "utxos" do
    field(:address, :string)
    field(:amount, :integer)
    field(:blknum, :integer)
    field(:oindex, :integer)
    field(:txbytes, :string)
    field(:txindex, :integer)
  end

  @doc false
  def changeset(transaction_db, attrs) do
    transaction_db
    |> cast(attrs, @field_names)
    |> validate_required(@field_names)
  end
end

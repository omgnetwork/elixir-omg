defmodule OmiseGOWatcher.UtxoDB do
  @moduledoc"""
  Template for creating (mix ecto.migrate) and using tables (database).
  """
  use Ecto.Schema
  import Ecto.Changeset

  @field_names [:address, :amount, :blknum, :txindex, :oindex, :txbytes]
  def field_names, do: @field_names

  schema "transactions" do
    field(:address, :string)
    field(:amount, :integer)
    field(:blknum, :integer)
    field(:txindex, :integer)
    field(:oindex, :integer)
    field(:txbytes, :string)
  end

  @doc false
  def changeset(utxo_db, attrs) do
    utxo_db
    |> cast(attrs, @field_names)
    |> validate_required(@field_names)
  end
end

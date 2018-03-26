defmodule OmisegoWallet.TransactionDB do
  @moduledoc """
  """
  use Ecto.Schema
  import Ecto.Changeset

  @field_names [:addres, :amount, :blknum, :oindex, :txbyte, :txindex]
  def field_names, do: @field_names

  schema "transactions" do
    field(:addres, :string)
    field(:amount, :integer)
    field(:blknum, :integer)
    field(:oindex, :integer)
    field(:txbyte, :string)
    field(:txindex, :integer)
  end

  @doc false
  def changeset(transaction_db, attrs) do
    transaction_db
    |> cast(attrs, @field_names)
    |> validate_required(@field_names)
  end
end

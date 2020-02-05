defmodule Engine.Transaction do
  @moduledoc """
  Transaction model.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @default_metadata <<0::160>>

  schema "transactions" do
    field(:tx_type, :integer, default: 1)
    field(:tx_data, :integer, default: 0)
    field(:metadata, :binary, default: @default_metadata)

    has_many(:inputs, Engine.Utxo, foreign_key: :spending_transaction_id)
    has_many(:outputs, Engine.Utxo, foreign_key: :creating_transaction_id)
  end

  def changeset(struct, params) do
    struct
    |> cast(params, [:tx_type, :tx_data, :metadata])
    |> validate_required([:tx_type, :tx_data, :metadata])
  end
end

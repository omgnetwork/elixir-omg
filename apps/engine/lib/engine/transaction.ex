defmodule Engine.Transaction do
  @moduledoc """
  Transaction model.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias __MODULE__

  @default_metadata <<0::160>>

  schema "transactions" do
    field(:tx_type, :integer, default: 1)
    field(:tx_data, :integer, default: 0)
    field(:metadata, :binary, default: @default_metadata)

    belongs_to(:block, Engine.Block)
    has_many(:inputs, Engine.Utxo, foreign_key: :spending_transaction_id)
    has_many(:outputs, Engine.Utxo, foreign_key: :creating_transaction_id)

    timestamps(type: :utc_datetime)
  end

  def build(txn) do
    fields = [tx_type: txn.tx_type, tx_data: txn.tx_data, metadata: txn.metadata]

    %__MODULE__{}
    |> change(fields)
    |> put_assoc(:inputs, Enum.map(txn.inputs, &Map.from_struct/1))
    |> put_assoc(:outputs, Enum.map(txn.outputs, &Map.from_struct/1))
  end

  def changeset(struct, params) do
    struct
    |> cast(params, [:tx_type, :tx_data, :metadata])
    |> validate_required([:tx_type, :tx_data, :metadata])
  end
end

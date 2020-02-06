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

  def build(transaction) do
    # record = Ecto.Changeset.change(%__MODULE__, [
    # tx_type: transaction.tx_type,
    # tx_data: transaction.tx_data,
    # metadata: transaction.metadata
    # ])

    # record = %Engine.Transaction{
    # }

    # Ecto.build_assoc(record, :inputs, 

    # inputs: Enum.map(transaction.inputs, fn input -> Map.from_struct(input) end),
    # outputs: Enum.map(transaction.outputs, fn output -> Map.from_struct(output) end),
  end

  def changeset(struct, params) do
    struct
    |> cast(params, [:tx_type, :tx_data, :metadata])
    |> validate_required([:tx_type, :tx_data, :metadata])
  end

  defp build_output_utxos(utxos) do
    Enum.map(utxos, fn utxo -> struct(Engine.Utxo, Map.to_list(utxo)) end)
  end
end

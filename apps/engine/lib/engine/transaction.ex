defmodule Engine.Transaction do
  @moduledoc """
  Transaction model.
  """

  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query, only: [from: 2]

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

  def build(%{} = txn) do
    fields = [tx_type: txn.tx_type, tx_data: txn.tx_data, metadata: txn.metadata]

    %__MODULE__{}
    |> change(fields)
    |> put_assoc(:inputs, Enum.map(txn.inputs, &Map.from_struct/1))
    |> put_assoc(:outputs, Enum.map(txn.outputs, &Map.from_struct/1))
  end

  def build(txn) do
    with {:ok, transaction} <- ExPlasma.decode(txn),
         do: build(transaction)
  end

  def changeset(struct, %ExPlasma.Transaction.Payment{} = params),
    do: changeset(struct, params_from_ex_plasma(params))

  def changeset(struct, %ExPlasma.Transaction.Deposit{} = params),
    do: changeset(struct, params_from_ex_plasma(params))

  def changeset(struct, %ExPlasma.Transaction{} = params),
    do: changeset(struct, params_from_ex_plasma(params))

  def changeset(struct, params) do
    struct
    |> Engine.Repo.preload(:inputs)
    |> Engine.Repo.preload(:outputs)
    |> cast(params, [:tx_type, :tx_data, :metadata])
    |> validate_required([:tx_type, :tx_data, :metadata])
    |> cast_assoc(:inputs)
    |> cast_assoc(:outputs)
    |> validate_usable_inputs()
  end

  @doc """
  Validates that the given changesets inputs are correct. To create a transaction with inputs:

    * The utxo position for the input must exist.
    * The utxo position for the input must not have been spent.
  """
  defp validate_usable_inputs(changeset) do
    positions =
      changeset
      |> get_field(:inputs)
      |> Enum.map(&ExPlasma.Utxo.pos/1)

    query = from(u in Engine.Utxo, where: u.pos in ^positions, limit: 4)
    result = Engine.Repo.all(query)

    if length(positions) != length(result) do
      missing_inputs = Enum.join(positions -- Enum.map(result, & &1.pos), ",")
      add_error(changeset, :inputs, "missing/spent input positions for #{missing_inputs}")
    else
      put_assoc(changeset, :inputs, result)
    end
  end

  defp params_from_ex_plasma(struct) do
    params = Map.from_struct(struct)

    %{
      params
      | inputs: Enum.map(struct.inputs, &Map.from_struct/1),
        outputs: Enum.map(struct.outputs, &Map.from_struct/1)
    }
  end
end

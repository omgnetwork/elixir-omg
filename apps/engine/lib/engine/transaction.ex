defmodule Engine.Transaction do
  @moduledoc """
  Transaction model.
  """

  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query, only: [from: 2]

  @default_metadata <<0::160>>

  @error_messages [
    cannot_be_zero: "can't be zero",
    exceeds_maximum: "can't exceed maximum value"
  ]

  schema "transactions" do
    field(:tx_type, :integer, default: 1)
    field(:tx_data, :integer, default: 0)
    field(:metadata, :binary, default: @default_metadata)

    belongs_to(:block, Engine.Block)
    has_many(:inputs, Engine.Utxo, foreign_key: :spending_transaction_id)
    has_many(:outputs, Engine.Utxo, foreign_key: :creating_transaction_id)

    timestamps(type: :utc_datetime)
  end

  def insert(params) do
    %__MODULE__{} |> changeset(params) |> Engine.Repo.insert()
  end

  defp changeset(struct, %{} = params) do
    struct
    |> Engine.Repo.preload(:inputs)
    |> Engine.Repo.preload(:outputs)
    |> cast(params, [:tx_type, :tx_data, :metadata])
    |> validate_required([:tx_type, :tx_data, :metadata])
    |> cast_assoc(:inputs)
    |> cast_assoc(:outputs)
    |> validate_usable_inputs()
  end

  defp changeset(struct, txbytes) when is_binary(txbytes) do
    case ExPlasma.decode(txbytes) do
      {:ok, transaction} ->
        changeset(struct, params_from_ex_plasma(transaction))

      {:error, {field, message}} ->
        struct |> changeset(%{}) |> add_error(field, @error_messages[message])
    end
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

    query =
      from(u in Engine.Utxo,
        where: u.pos in ^positions and is_nil(u.spending_transaction_id),
        limit: 4
      )

    result = Engine.Repo.all(query)

    if length(positions) != length(result) do
      missing_inputs = Enum.join(positions -- Enum.map(result, & &1.pos), ",")
      add_error(changeset, :inputs, "input utxos #{missing_inputs} are missing or spent")
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

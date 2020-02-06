defmodule Engine.Utxo do
  @moduledoc """
  Ecto schema for UTXOs in the system. The UTXO can exist in two forms:

  * Being built, as a new unspent output (UTXO). Since the blocks have not been formed, the full utxo position
  information does not exist for the given UTXO. We only really know the oindex at this point.

  * Being formed into a block via the transaction. At this point we should have all the information available to
  create a full UTXO position for this.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @default_eth_address <<0::160>>

  @error_messages [
    cannot_be_zero: "can't be zero",
    exceeds_maximum: "can't exceed maximum value"
  ]

  schema "utxos" do
    # UTXO position information
    field(:pos, :integer)
    field(:blknum, :integer)
    field(:txindex, :integer)
    field(:oindex, :integer)

    # UTXO output information
    field(:output_type, :integer, default: 1)
    field(:owner, :binary)
    field(:currency, :binary, default: @default_eth_address)
    field(:amount, :integer, default: 0)

    belongs_to(:spending_transaction, Engine.Utxo)
    belongs_to(:creating_transaction, Engine.Utxo)

    timestamps(type: :utc_datetime)
  end

  @doc """
  """
  def changeset(struct, params) do
    struct
    |> cast(params, [:blknum, :txindex, :oindex, :output_type, :owner, :currency, :amount])
    |> validate_required([:output_type, :owner, :currency, :amount])
    |> validate_output()
    |> validate_input()
    |> unique_constraint(:pos)
  end

  def set_position(changeset, %{blknum: _, txindex: _, oindex: _} = position) do
    params = Map.put_new(position, :pos, ExPlasma.Utxo.pos(position))
    change(changeset, params)
  end

  defp validate_output(changeset), do: validate_protocol([:owner, :currency, :amount])
  defp validate_input(changeset), do: validate_protocol([:blknum, :txindex, :oindex])

  defp validate_protocol(changeset, keys) do
    params = Enum.map(keys, fn key -> {key, get_field(changeset, key)} end)
    do_validate_protocol(changeset, params)
  end

  defp do_validate_protocol(changeset, blknum: nil, txindex: _, oindex: _), do: changeset

  defp do_validate_protocol(changeset, keywords) do
    params = Enum.into(keywords, %{})

    case ExPlasma.Utxo.new(struct(%ExPlasma.Utxo{}, params)) do
      {:ok, _utxo} -> changeset
      {:error, {attribute, message}} -> add_error(changeset, attribute, @error_messages[message])
    end
  end
end

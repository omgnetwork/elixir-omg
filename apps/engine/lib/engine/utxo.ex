defmodule Engine.Utxo do
  @moduledoc """
  Ecto schema for UTXOs in the system.
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
    field(:pos, :integer, default: 0)
    field(:blknum, :integer, default: 0)
    field(:txindex, :integer, default: 0)
    field(:oindex, :integer, default: 0)

    # UTXO output information
    field(:output_type, :integer, default: 1)
    field(:owner, :binary)
    field(:currency, :binary, default: @default_eth_address)
    field(:amount, :integer, default: 0)

    field(:spent, :boolean)
  end

  @doc """
  Changeset for UTXO inputs. Validates the inputs and generates the utxo position.
  """
  def input_changeset(struct, params) do
    struct
    |> cast(params, [:blknum, :txindex, :oindex])
    |> validate_required([:blknum, :txindex, :oindex])
    |> validate_input()
    |> set_pos()
  end

  @doc """
  Changeset for UTXO outputs.
  """
  def output_changeset(struct, params) do
    struct
    |> cast(params, [:output_type, :owner, :currency, :amount])
    |> validate_required([:output_type, :owner, :currency, :amount])
    |> validate_output()
  end

  defp validate_input(changeset) do
    validate_stateless(changeset, %{
      blknum: get_field(changeset, :blknum),
      txindex: get_field(changeset, :txindex),
      oindex: get_field(changeset, :oindex)
    })
  end

  defp validate_output(changeset) do
    validate_stateless(changeset, %{
      owner: get_field(changeset, :owner),
      currency: get_field(changeset, :currency),
      amount: get_field(changeset, :amount)
    })
  end

  defp validate_stateless(changeset, params) do
    case ExPlasma.Utxo.new(struct(%ExPlasma.Utxo{}, params)) do
      {:ok, _utxo} -> changeset
      {:error, {attribute, message}} -> add_error(changeset, attribute, @error_messages[message])
    end
  end

  defp set_pos(changeset) do
    blknum = get_field(changeset, :blknum)
    txindex = get_field(changeset, :txindex)
    oindex = get_field(changeset, :oindex)
    pos = ExPlasma.Utxo.pos(%{blknum: blknum, txindex: txindex, oindex: oindex})

    put_change(changeset, :pos, pos)
  end
end

defmodule OmiseGO.API.UtxoPosition do
  @moduledoc """
  Representation of a utxo position.
  """

  @block_offset 1_000_000_000
  @transaction_offset 10_000

  defstruct [:blknum, :txindex, :oindex]

  @type t() :: %__MODULE__{
          blknum: pos_integer,
          txindex: pos_integer,
          oindex: pos_integer
        }

  @spec encode_utxo_position(t()) :: {:ok, pos_integer()} | {:error, :invalid_utxo_position}
  def encode_utxo_position(%__MODULE__{blknum: blknum, txindex: txindex, oindex: oindex}),
    do: blknum * @block_offset + txindex * @transaction_offset + oindex

  @spec decode_utxo_position(pos_integer()) :: {:ok, t()} | {:error, :invalid_utxo_position}
  def decode_utxo_position(encoded) when encoded > @block_offset do
    blknum = div(encoded, @block_offset)
    txindex = encoded |> rem(@block_offset) |> div(@transaction_offset)
    oindex = rem(encoded, @transaction_offset)

    %__MODULE__{blknum: blknum, txindex: txindex, oindex: oindex}
  end
end

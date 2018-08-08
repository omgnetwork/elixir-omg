defmodule OmiseGO.API.Utxo.Position do
  @moduledoc """
  Representation of a UTXO position in the child chain, providing encoding/decoding to/from format digestible in Eth
  """

  # these two offset constants are driven by the constants from the RootChain.sol contract
  @block_offset 1_000_000_000
  @transaction_offset 10_000

  alias OmiseGO.API.Utxo
  require Utxo

  @type t() :: {
          :utxo_position,
          # blknum
          pos_integer,
          # txindex
          non_neg_integer,
          # oindex
          non_neg_integer
        }

  @spec encode(t()) :: pos_integer()
  def encode(Utxo.position(blknum, txindex, oindex)),
    do: blknum * @block_offset + txindex * @transaction_offset + oindex

  @spec decode(pos_integer()) :: t()
  def decode(encoded) when encoded >= @block_offset do
    blknum = div(encoded, @block_offset)
    txindex = encoded |> rem(@block_offset) |> div(@transaction_offset)
    oindex = rem(encoded, @transaction_offset)

    Utxo.position(blknum, txindex, oindex)
  end
end

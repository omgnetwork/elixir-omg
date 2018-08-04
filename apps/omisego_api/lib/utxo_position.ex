defmodule OmiseGO.API.UtxoPosition do
  @moduledoc """
  Representation of a utxo position, handles the encoding/decoding to/from single integer required by the contract
  """

  @block_offset 1_000_000_000
  @transaction_offset 10_000

  @type t() :: {
          pos_integer,
          non_neg_integer,
          non_neg_integer
        }

  defmacro new(blknum, txindex, oindex) do
    quote do
      {unquote(blknum), unquote(txindex), unquote(oindex)}
    end
  end


  @spec encode(t()) :: pos_integer()
  def encode(new(blknum, txindex, oindex)),
    do: blknum * @block_offset + txindex * @transaction_offset + oindex

  @spec decode(pos_integer()) :: t()
  def decode(encoded) when encoded > @block_offset do
    blknum = div(encoded, @block_offset)
    txindex = encoded |> rem(@block_offset) |> div(@transaction_offset)
    oindex = rem(encoded, @transaction_offset)

    new(blknum, txindex, oindex)
  end
end

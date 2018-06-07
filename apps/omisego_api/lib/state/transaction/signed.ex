defmodule OmiseGO.API.State.Transaction.Signed do
  @moduledoc false

  alias OmiseGO.API.State.Transaction
  alias OmiseGO.API.Crypto

  @signature_length 65

  defstruct [:raw_tx, :sig1, :sig2]
  @type t() :: %__MODULE__{
    raw_tx: Transaction.t(),
    sig1: <<_::520>>,
    sig2: <<_::520>>
  }

  def signed_hash(%__MODULE__{raw_tx: tx, sig1: sig1, sig2: sig2}) do
    Transaction.hash(tx) <> sig1 <> sig2
  end

  def encode(%__MODULE__{raw_tx: tx, sig1: sig1, sig2: sig2}) do
    [
      tx.blknum1,
      tx.txindex1,
      tx.oindex1,
      tx.blknum2,
      tx.txindex2,
      tx.oindex2,
      tx.newowner1,
      tx.amount1,
      tx.newowner2,
      tx.amount2,
      tx.fee,
      sig1,
      sig2
    ]
    |> ExRLP.encode()
  end

  def decode(line) do
    with {:ok, tx} <- rlp_decode(line),
         {:ok, tx} <- reconstruct_tx(tx),
         do: {:ok, tx}
  end

  defp int_parse(int), do: :binary.decode_unsigned(int, :big)

  defp rlp_decode(line) do
    try do
      {:ok, ExRLP.decode(line)}
    catch
      _ ->
        {:error, :malformed_transaction_rlp}
    end
  end

  defp reconstruct_tx(encoded_singed_tx) do
    case encoded_singed_tx do
      [
        blknum1,
        txindex1,
        oindex1,
        blknum2,
        txindex2,
        oindex2,
        newowner1,
        amount1,
        newowner2,
        amount2,
        fee,
        sig1,
        sig2
      ] ->
        with :ok <- signature_length?(sig1),
             :ok <- signature_length?(sig2) do
          tx = %Transaction{
            blknum1: int_parse(blknum1),
            txindex1: int_parse(txindex1),
            oindex1: int_parse(oindex1),
            blknum2: int_parse(blknum2),
            txindex2: int_parse(txindex2),
            oindex2: int_parse(oindex2),
            newowner1: address_parse(newowner1),
            amount1: int_parse(amount1),
            newowner2: address_parse(newowner2),
            amount2: int_parse(amount2),
            fee: int_parse(fee)
          }

          {:ok,
           %__MODULE__{
             raw_tx: tx,
             sig1: sig1,
             sig2: sig2
           }}
        end

      _tx ->
        {:error, :malformed_transaction}
    end
  end

  # necessary, because RLP handles empty string equally to integer 0
  defp address_parse(""), do: 0
  defp address_parse(<<_::160>> = address_bytes), do: address_bytes

  defp signature_length?(sig) when byte_size(sig) == @signature_length, do: :ok
  defp signature_length?(_sig), do: {:error, :bad_signature_length}
end

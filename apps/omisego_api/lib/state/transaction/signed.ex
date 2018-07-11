defmodule OmiseGO.API.State.Transaction.Signed do
  @moduledoc false

  alias OmiseGO.API.Crypto
  alias OmiseGO.API.State.Transaction

  @signature_length 65
  @type signed_tx_bytes_t() :: bitstring() | nil

  defstruct [:raw_tx, :sig1, :sig2, :signed_tx_bytes]

  @type t() :: %__MODULE__{
          raw_tx: Transaction.t(),
          sig1: Crypto.sig_t(),
          sig2: Crypto.sig_t(),
          signed_tx_bytes: signed_tx_bytes_t()
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
      tx.cur12,
      tx.newowner1,
      tx.amount1,
      tx.newowner2,
      tx.amount2,
      sig1,
      sig2
    ]
    |> ExRLP.encode()
  end

  def decode(signed_tx_bytes) do
    with {:ok, tx} <- rlp_decode(signed_tx_bytes),
         do: reconstruct_tx(tx, signed_tx_bytes)
  end

  defp rlp_decode(line) do
    try do
      {:ok, ExRLP.decode(line)}
    rescue
      _ -> {:error, :malformed_transaction_rlp}
    end
  end

  defp reconstruct_tx(
         [
           blknum1,
           txindex1,
           oindex1,
           blknum2,
           txindex2,
           oindex2,
           cur12,
           newowner1,
           amount1,
           newowner2,
           amount2,
           sig1,
           sig2
         ],
         signed_tx_bytes
       ) do
    with :ok <- signature_length?(sig1),
         :ok <- signature_length?(sig2),
         {:ok, parsed_cur12} <- address_parse(cur12),
         {:ok, parsed_newowner1} <- address_parse(newowner1),
         {:ok, parsed_newowner2} <- address_parse(newowner2) do
      tx = %Transaction{
        blknum1: int_parse(blknum1),
        txindex1: int_parse(txindex1),
        oindex1: int_parse(oindex1),
        blknum2: int_parse(blknum2),
        txindex2: int_parse(txindex2),
        oindex2: int_parse(oindex2),
        cur12: parsed_cur12,
        newowner1: parsed_newowner1,
        amount1: int_parse(amount1),
        newowner2: parsed_newowner2,
        amount2: int_parse(amount2)
      }

      {:ok,
       %__MODULE__{
         raw_tx: tx,
         sig1: sig1,
         sig2: sig2,
         signed_tx_bytes: signed_tx_bytes
       }}
    end
  end

  # essentially - wrong number of fields after rlp deconding
  defp reconstruct_tx(__singed_tx, _signed_tx_bytes) do
    {:error, :malformed_transaction}
  end

  defp int_parse(int), do: :binary.decode_unsigned(int, :big)

  # necessary, because RLP handles empty string equally to integer 0
  @spec address_parse(<<>> | Crypto.address_t()) :: {:ok, Crypto.address_t()} | {:error, :malformed_address}
  defp address_parse(address)
  defp address_parse(""), do: {:ok, <<0::160>>}
  defp address_parse(<<_::160>> = address_bytes), do: {:ok, address_bytes}
  defp address_parse(_), do: {:error, :malformed_address}

  defp signature_length?(sig) when byte_size(sig) == @signature_length, do: :ok
  defp signature_length?(_sig), do: {:error, :bad_signature_length}
end

defmodule OmiseGO.API.State.Transaction do
  @moduledoc """
  Internal representation of a spend transaction on Plasma chain
  """

  alias OmiseGO.API.Crypto

  @zero_address <<0>> |> List.duplicate(20) |> Enum.join

  # TODO: probably useful to structure these fields somehow ore readable like
  # defstruct [:input1, :input2, :output1, :output2, :fee], with in/outputs as structs or tuples?
  defstruct [:blknum1,
             :txindex1,
             :oindex1,
             :blknum2,
             :txindex2,
             :oindex2,
             :newowner1,
             :amount1,
             :newowner2,
             :amount2,
             :fee,
             ]

  defmodule Signed do

    @signature_length 64

    @moduledoc false
    defstruct [:raw_tx, :sig1, :sig2, :hash]

    def hash(%__MODULE__{raw_tx: tx, sig1: sig1, sig2: sig2} = signed) do
      hash =
        (OmiseGO.API.State.Transaction.hash(tx) <> sig1 <> sig2)
        |> Crypto.hash()
      %{signed | hash: hash}
    end

    def encode(%__MODULE__{} = singed_tx) do
      tx = singed_tx.raw_tx

      [tx.blknum1,
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
        singed_tx.hash,
        singed_tx.sig1,
        singed_tx.sig2]
        |> ExRLP.encode
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
        [blknum1, txindex1, oindex1,
          blknum2, txindex2, oindex2,
          newowner1, amount1, newowner2, amount2,
          fee, hash, sig1, sig2] ->

            tx = %OmiseGO.API.State.Transaction{
              blknum1: int_parse(blknum1),
              txindex1: int_parse(txindex1),
              oindex1: int_parse(oindex1),
              blknum2: int_parse(blknum2),
              txindex2: int_parse(txindex2),
              oindex2: int_parse(oindex2),
              newowner1: newowner1,
              amount1: int_parse(amount1),
              newowner2: newowner2,
              amount2: int_parse(amount2),
              fee: int_parse(fee)}

            {:ok,
             %__MODULE__{
               raw_tx: tx,
               hash: hash,
               sig1: sig1,
               sig2: sig2
            }}

        _tx ->
          {:error, :malformed_transaction}

      end
    end
  end

  defmodule Recovered do
    @moduledoc """
    Representation of a Signed transaction, with addresses recovered from signatures (from Transaction.Signed)
    Intent is to allow concurent processing of signatures outside of serial processing in state.ex
    """

    # FIXME: refactor to somewhere to avoid dupliaction
    @zero_address <<0>> |> List.duplicate(20) |> Enum.join

    # FIXME: rethink default values
    defstruct [:signed, spender1: @zero_address, spender2: @zero_address]

    def recover_from(%OmiseGO.API.State.Transaction.Signed{raw_tx: raw_tx, sig1: sig1, sig2: sig2, hash: hash} = signed) do
       hash_no_spenders = OmiseGO.API.State.Transaction.hash(raw_tx)
       {:ok, spender1} = Crypto.recover_address(hash_no_spenders, sig1)
       {:ok, spender2} = Crypto.recover_address(hash_no_spenders, sig2)
       %__MODULE__{signed: signed, spender1: spender1, spender2: spender2}
    end
  end

  # TODO: add convenience function for creating common transactions (1in-1out, 1in-2out-with-change, etc.)

  def zero_address, do: @zero_address

  def account_address?(address), do: address != @zero_address

  def encode(%__MODULE__{} = tx) do
    [tx.blknum1,
      tx.txindex1,
      tx.oindex1,
      tx.blknum2,
      tx.txindex2,
      tx.oindex2,
      tx.newowner1,
      tx.amount1,
      tx.newowner2,
      tx.amount2,
      tx.fee]
      |> ExRLP.encode
  end

  def hash(%__MODULE__{} = tx) do
    tx
    |> encode
    |> Crypto.hash()
  end

end

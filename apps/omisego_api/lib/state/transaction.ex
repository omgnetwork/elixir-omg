defmodule OmiseGO.API.State.Transaction do
  @moduledoc """
  Internal representation of a spend transaction on Plasma chain
  """

  alias OmiseGO.API.Crypto

  @zero_address <<0::size(160)>>

  # TODO: probably useful to structure these fields somehow ore readable like
  # defstruct [:input1, :input2, :output1, :output2, :fee], with in/outputs as structs or tuples?
  defstruct blknum1: 0,
            txindex1: 0,
            oindex1: 0,
            blknum2: 0,
            txindex2: 0,
            oindex2: 0,
            newowner1: 0,
            amount1: 0,
            newowner2: 0,
            amount2: 0,
            fee: 0

  def create_from_utxos(
        %{"address" => change_address, "utxos" => utxos},
        %{address: receiver_address, amount: amount},
        fee
      ) do
    stream_parts_transaction =
      utxos |> Enum.with_index(1)
      |> Enum.map(fn {utxo, number} ->
        %{
          :"blknum#{number}" => utxo["blknum"],
          :"txindex#{number}" => utxo["txindex"],
          :"oindex#{number}" => utxo["oindex"],
          amount: utxo["amount"]
        }
      end)

    all_amount = Enum.reduce(stream_parts_transaction, 0, &(&1.amount + &2))

    transaction =
      Enum.reduce(stream_parts_transaction, %{}, fn part_transaction, acc ->
        {_, part_transaction} = Map.pop(part_transaction, :amount)
        Map.merge(acc, part_transaction)
      end)

    transaction =
      struct!(
        __MODULE__,
        Map.merge(transaction, %{
          newowner1: receiver_address,
          amount1: amount,
          newowner2: change_address,
          amount2: all_amount - amount - fee,
          fee: fee
        })
      )

    case validate(transaction) do
      :ok -> {:ok, transaction}
      {:error, _reason} = error -> error
    end
  end

  def validate(%__MODULE__{} = transaction) do
    cond do
      transaction.amount1 < 0 -> {:error, :amount_negative_value}
      transaction.amount2 < 0 -> {:error, :amount_negative_value}
      transaction.fee < 0 -> {:error, :fee_negative_value}
      true -> :ok
    end
  end

  defmodule Signed do
    @moduledoc false

    alias OmiseGO.API.State.Transaction

    @signature_length 65

    defstruct [:raw_tx, :sig1, :sig2]

    def hash(%__MODULE__{raw_tx: tx, sig1: sig1, sig2: sig2}) do
      (Transaction.hash(tx) <> sig1 <> sig2)
      |> Crypto.hash()
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
              newowner1: newowner1,
              amount1: int_parse(amount1),
              newowner2: newowner2,
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

    defp signature_length?(sig) when byte_size(sig) == @signature_length, do: :ok
    defp signature_length?(_sig), do: {:error, :bad_signature_length}
  end

  defmodule Recovered do
    @moduledoc """
    Representation of a Signed transaction, with addresses recovered from signatures (from Transaction.Signed)
    Intent is to allow concurent processing of signatures outside of serial processing in state.ex
    """
    alias OmiseGO.API.State.Transaction

    alias OmiseGO.API.State.Transaction

    @empty_signature <<0::size(520)>>

    defstruct [:raw_tx, :signed_tx_hash, spender1: nil, spender2: nil]

    def recover_from(%Transaction.Signed{raw_tx: raw_tx, sig1: sig1, sig2: sig2} = signed_tx) do
      hash_no_spenders = Transaction.hash(raw_tx)
      spender1 = get_spender(hash_no_spenders, sig1)
      spender2 = get_spender(hash_no_spenders, sig2)

      hash = Transaction.Signed.hash(signed_tx)

      %__MODULE__{raw_tx: raw_tx, signed_tx_hash: hash, spender1: spender1, spender2: spender2}
    end

    defp get_spender(hash_no_spenders, sig) do
      case sig do
        @empty_signature ->
          nil

        _ ->
          {:ok, spender} = Crypto.recover_address(hash_no_spenders, sig)
          spender
      end
    end
  end

  # TODO: add convenience function for creating common transactions (1in-1out, 1in-2out-with-change, etc.)

  def zero_address, do: @zero_address

  def account_address?(address), do: address != @zero_address

  def encode(%__MODULE__{} = tx) do
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
      tx.fee
    ]
    |> ExRLP.encode()
  end

  def hash(%__MODULE__{} = tx) do
    tx
    |> encode
    |> Crypto.hash()
  end

  def sign(%__MODULE__{} = tx, priv1, priv2) do
    encoded_tx = encode(tx)
    signature1 = Crypto.signature(encoded_tx, priv1)
    signature2 = Crypto.signature(encoded_tx, priv2)

    %Signed{raw_tx: tx, sig1: signature1, sig2: signature2}
  end

end

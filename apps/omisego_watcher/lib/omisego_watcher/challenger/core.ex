defmodule OmiseGOWatcher.Challenger.Core do
  @moduledoc """
  Functional core of challenger
  """

  alias OmiseGO.API.Block
  alias OmiseGO.API.State.Transaction
  alias OmiseGO.API.State.Transaction.Recovered
  alias OmiseGOWatcher.Challenger.Challenge
  alias OmiseGOWatcher.TransactionDB

  @block_offset 1_000_000_000
  @transaction_offset 10_000

  @spec create_challenge(%TransactionDB{}, list(%TransactionDB{}), map()) :: Challenge.t()
  def create_challenge(challenging_tx, txs, utxo_exit) do
    txbytes = encode(challenging_tx)
    eutxoindex = get_eutxo_index(challenging_tx, utxo_exit)
    cutxopos = challenging_utxo_pos(challenging_tx)

    recovered_txs =
      txs
      |> Enum.sort_by(& &1.txindex)
      |> Enum.map(fn tx -> %Recovered{signed_tx_hash: tx.txid} end)

    proof = Block.create_tx_proof(%Block{transactions: recovered_txs}, challenging_tx.txindex)

    Challenge.create(cutxopos, eutxoindex, txbytes, proof, challenging_tx.sig1 <> challenging_tx.sig2)
  end

  defp encode(%TransactionDB{
         blknum1: blknum1,
         txindex1: txindex1,
         oindex1: oindex1,
         blknum2: blknum2,
         txindex2: txindex2,
         oindex2: oindex2,
         cur12: cur12,
         newowner1: newowner1,
         amount1: amount1,
         newowner2: newowner2,
         amount2: amount2
       }) do
    tx = %Transaction{
      blknum1: blknum1,
      txindex1: txindex1,
      oindex1: oindex1,
      blknum2: blknum2,
      txindex2: txindex2,
      oindex2: oindex2,
      cur12: cur12,
      newowner1: newowner1,
      amount1: amount1,
      newowner2: newowner2,
      amount2: amount2
    }

    Transaction.encode(tx)
  end

  defp get_eutxo_index(%TransactionDB{blknum1: blknum1, txindex1: txindex1, oindex1: oindex1}, %{
         blknum: blknum,
         txindex: txindex,
         oindex: oindex
       })
       when blknum == blknum1 and txindex == txindex1 and oindex == oindex1,
       do: 0

  defp get_eutxo_index(_, _), do: 1

  defp challenging_utxo_pos(challenging_tx) do
    challenging_tx
    |> get_challenging_utxo()
    |> utxo_pos()
  end

  defp get_challenging_utxo(%TransactionDB{txblknum: blknum, txindex: txindex, amount1: 0}),
    do: %{blknum: blknum, txindex: txindex, oindex: 1}

  defp get_challenging_utxo(%TransactionDB{txblknum: blknum, txindex: txindex}),
    do: %{blknum: blknum, txindex: txindex, oindex: 0}

  defp utxo_pos(%{blknum: blknum, txindex: txindex, oindex: oindex}),
    do: blknum * @block_offset + txindex * @transaction_offset + oindex

  def decode_utxo_pos(encoded) do
    blknum = div(encoded, @block_offset)
    txindex = encoded |> rem(@block_offset) |> div(@transaction_offset)
    oindex = rem(encoded, @transaction_offset)
    %{blknum: blknum, txindex: txindex, oindex: oindex}
  end
end

defmodule OmiseGOWatcher.Challenger do
  @moduledoc """
  Manages challenges of exits
  """

  alias OmiseGO.API.UtxoPosition
  alias OmiseGOWatcher.Challenger.Challenge
  alias OmiseGOWatcher.Challenger.Core
  alias OmiseGOWatcher.TransactionDB

  def challenge(_utxo_exit) do
    :challenged
  end

  @doc """
  Returns challenge for an exit
  """
  @spec create_challenge(pos_integer(), non_neg_integer(), non_neg_integer()) :: Challenge.t() | :exit_valid
  def create_challenge(blknum, txindex, oindex) do
    utxo_exit = %UtxoPosition{blknum: blknum, txindex: txindex, oindex: oindex}

    with {:ok, challenging_tx} <- TransactionDB.get_transaction_challenging_utxo(utxo_exit) do
      txs_in_challenging_block = TransactionDB.find_by_txblknum(challenging_tx.txblknum)
      Core.create_challenge(challenging_tx, txs_in_challenging_block, utxo_exit)
    else
      :utxo_not_spent -> :exit_valid
    end
  end
end

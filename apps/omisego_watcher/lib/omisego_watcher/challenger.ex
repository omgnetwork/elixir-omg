defmodule OmiseGOWatcher.Challenger do
  @moduledoc """
  Manages challenges of exits
  """

  alias OmiseGOWatcher.Challenger.Challenge
  alias OmiseGOWatcher.Challenger.Core

  def challenge(_utxo_exit) do
    :challenged
  end

  @doc """
  Returns challenge for an exit
  """
  @spec create_challenge(pos_integer()) :: Challenge.t() | :exit_valid
  def create_challenge(encoded_utxo_exit) do
    utxo_exit = Core.decode_utxo_pos(encoded_utxo_exit)
    with {:ok, offending_tx} <- OmiseGOWatcher.TransactionDB.get_transaction_spending_utxo(utxo_exit) do
      txs_in_offending_block = OmiseGOWatcher.TransactionDB.get_transactions_from_block(offending_tx.txblknum)
      Core.create_challenge(offending_tx, txs_in_offending_block, utxo_exit)
    else
      :utxo_not_spent -> :exit_valid
    end
  end
end

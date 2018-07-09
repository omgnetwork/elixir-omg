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

    with {:ok, challenging_tx} <- OmiseGOWatcher.TransactionDB.get_transaction_challenging_utxo(utxo_exit) do
      txs_in_challenging_block = OmiseGOWatcher.TransactionDB.find_by_txblknum(challenging_tx.txblknum)
      Core.create_challenge(challenging_tx, txs_in_challenging_block, utxo_exit)
    else
      :utxo_not_spent -> :exit_valid
    end
  end
end

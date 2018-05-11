defmodule OmiseGOWatcher.FastExitValidator do
  @moduledoc """
  Detects exits for spent utxos and notifies challenger
  """

  alias OmiseGOWatcher.ExitValidator.Core

  def start_link do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def sync_eth_height(synced_eth_height) do
    GenServer.cast(__MODULE__, {:validate_exits, synced_eth_height})
  end

  use GenServer

  def init(:ok) do
    with {:ok, last_exit_eth_height} <- OmiseGO.DB.last_exit_block_height() do
      {:ok, %Core{last_exit_eth_height: last_exit_eth_height}}
    end
  end

  def handle_cast({:validate_exits, synced_eth_height}, state) do
    with {block_from, block_to, state, db_updates} <- Core.get_exits_block_range(state, synced_eth_height),
         utxo_exits <- OmiseGO.Eth.get_exits(block_from, block_to),
         :ok <- validate_exits(utxo_exits),
         :ok <- OmiseGO.DB.multi_update(db_updates) do
      {:noreply, state}
    else
      :empty_range -> {:noreply, state}
    end
  end

  defp validate_exits(utxo_exits) do
    for utxo_exit <- utxo_exits do
      :ok = validate_exit(utxo_exit)
    end

    :ok
  end

  defp validate_exit(%{blknum: blknum, txindex: txindex, oindex: oindex} = utxo_exit) do
    with :utxo_does_not_exists <- OmiseGO.API.State.utxo_exists(%{blknum: blknum, txindex: txindex, oindex: oindex}),
         :challenged <- OmiseGOWatcher.Challenger.challenge(utxo_exit) do
      :ok
    else
      :utxo_exists -> :ok
    end
  end
end

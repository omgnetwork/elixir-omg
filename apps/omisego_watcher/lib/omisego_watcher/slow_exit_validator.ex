defmodule OmiseGOWatcher.SlowExitValidator do
  @moduledoc """
  Detects exits for spent utxos and notifies challenger
  """

  alias OmiseGOWatcher.ExitValidator.Core

  def start_link(slow_exit_validator_block_margin) do
    GenServer.start_link(__MODULE__, slow_exit_validator_block_margin, name: __MODULE__)
  end

  def sync_eth_height(synced_eth_height) do
    GenServer.cast(__MODULE__, {:validate_exits, synced_eth_height})
  end

  use GenServer

  def init(slow_exit_validator_block_margin) do
    with {:ok, last_exit_block_height} <- OmiseGO.DB.last_slow_exit_block_height() do
      {:ok,
       %Core{
         last_exit_block_height: last_exit_block_height,
         update_key: :last_slow_exit_block_height,
         margin_on_synced_block: slow_exit_validator_block_margin
       }}
    end
  end

  def handle_cast({:validate_exits, synced_eth_block_height}, state) do
    with {block_from, block_to, state, db_updates} <- Core.get_exits_block_range(state, synced_eth_block_height),
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
    with :utxo_does_not_exist <- OmiseGO.API.State.utxo_exists(%{blknum: blknum, txindex: txindex, oindex: oindex}),
         :challenged <- OmiseGOWatcher.Challenger.challenge(utxo_exit) do
      :ok
    else
      :utxo_exists -> spend_utxo(utxo_exit)
    end
  end

  defp spend_utxo(utxo_exit) do
    with :ok <- OmiseGO.API.State.exit_utxos([utxo_exit]) do
      :ok
    else
      :utxo_does_not_exist ->
        :ok = OmiseGOWatcher.ChainExiter.exit()
        :child_chain_exit
    end
  end
end

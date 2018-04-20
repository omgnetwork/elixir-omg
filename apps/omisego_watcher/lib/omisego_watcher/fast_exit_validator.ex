defmodule OmiseGOWatcher.FastExitValidator do
  @moduledoc"""
  Detects exits for spent utxos and notifies challenger.
  """

  def start_link do
    GenServer.start_link(__MODULE__, :ok)
  end

  def validate_exit(utxo_exit) do
    GenServer.call(__MODULE__, {:exit_utxo, utxo_exit})
  end

  use GenServer

  def init(:ok) do
    {:ok, nil}
  end

  def handle_call({:exit_utxo, %{blknum: blknum, txindex: txindex, oindex: oindex} = utxo_exit}, state) do
    with :utxo_does_not_exists <- OmiseGO.API.State.utxo_exists(%{blknum: blknum, txindex: txindex, oindex: oindex}),
         :challenged <- OmiseGOWatcher.Challenger.challenge(utxo_exit) do
      {:reply, :ok, state}
    else
      :exit_exists -> {:reply, :ok, state}
      :utxo_exists -> {:reply, :ok, state}
    end
  end

end

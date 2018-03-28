defmodule OmiseGO.API.Depositor do
  @moduledoc """
  Keeps track of deposits
  """

  alias OmiseGO.Eth
  alias OmiseGO.API.Depositor.Core
  alias OmiseGO.API.State

  ### Client

  def start_link do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  ### Server

  use GenServer

  def init(:ok) do
    schedule_get_deposits(0)
    {:ok, %Core{}}
  end

  def handle_info(:get_deposits, state) do
    with {:ok, eth_block_height} <- Eth.get_ethereum_height(),
         {:ok, new_state, next_get_deposits_interval, block_from, block_to}
           <- Core.get_deposit_block_range(state, eth_block_height),
         {:ok, deposits} <- Eth.get_deposits(block_from, block_to),
         :ok <- State.deposit(deposits) do
           schedule_get_deposits(next_get_deposits_interval)
           {:no_reply, new_state}
    else
      _ -> {:stop, :failed_to_get_deposits, state}
    end
  end

  defp schedule_get_deposits(interval) do
    Process.send_after(self(), :get_deposits, interval)
  end
end

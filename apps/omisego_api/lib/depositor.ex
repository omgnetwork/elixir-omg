defmodule OmiseGO.API.Depositor do
  @moduledoc """
  Periodically fetches deposits made on dynamically changing block range
  on parent chain and feeds them to state.
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
    #TODO: initialize state with the last ethereum block we have seen deposits from
    with {:ok, parent_start} <- Eth.get_root_deployment_height() do
      schedule_get_deposits(0)
      {:ok, %Core{last_deposit_block: parent_start}}
    end
  end

  def handle_info(:get_deposits, state) do
    with {:ok, eth_block_height} <- Eth.get_ethereum_height(),
         {:ok, new_state, next_get_deposits_interval, eth_block_from, eth_block_to} <-
           Core.get_deposit_block_range(state, eth_block_height),
         {:ok, deposits} <- Eth.get_deposits(eth_block_from, eth_block_to),
         :ok <- State.deposit(deposits) do
      schedule_get_deposits(next_get_deposits_interval)
      {:no_reply, new_state}
    else
      {:no_blocks_with_deposit, state, next_get_deposits_interval} ->
        schedule_get_deposits(next_get_deposits_interval)
        {:no_reply, state}
      _ -> {:stop, :failed_to_get_deposits, state}
    end
  end

  defp schedule_get_deposits(interval) do
    Process.send_after(self(), :get_deposits, interval)
  end
end

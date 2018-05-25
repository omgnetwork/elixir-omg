defmodule OmiseGOWatcher.BlockGetter do
  @moduledoc """
  tracking block on child chain
  """
  use GenServer
  alias OmiseGOWatcher.{UtxoDB, BlockValidator}
  alias OmiseGO.API.Block
  alias OmiseGO.Eth

  defp ask_for_block(from, to, contract) when from <= to do
    with {:ok, {hash, _time}} <- Eth.get_child_chain(from, contract),
         {:ok, json_block} <- OmiseGO.JSONRPC.Client.call(:get_block, %{hash: hash}),
         {:ok, %Block{} = block} <- BlockValidator.json_to_block(json_block, from) do
      UtxoDB.consume_block(block, from)
      OmiseGOWatcher.TransactionDB.insert(block, from)
      ask_for_block(from + Application.get_env(:omisego_eth, :child_block_interval), to, contract)
    else
      _ -> {:error, from - 1_000}
    end
  end

  defp ask_for_block(_, to, _), do: {:ok, to}

  def start_link(_args) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(_opts) do
    with {:ok, block_number} <- OmiseGO.DB.child_top_block_number(),
         {:ok, _} <- :timer.send_after(0, self(), :check_for_new_block) do
      {:ok,
       %{
         child_block_number: block_number,
         contract_address: Application.get_env(:omisego_eth, :contract_address)
       }}
    else
      _ -> {:error, :init_block_getter}
    end
  end

  def handle_call(:get_height, _from, state) do
    {:reply, state.child_block_number, state}
  end

  def handle_info(:check_for_new_block, state) do
    {:ok, child_block} = OmiseGO.Eth.get_current_child_block(state.contract_address)
    child_block_interval = Application.get_env(:omisego_eth, :child_block_interval)
    child_block = child_block - child_block_interval

    if child_block > state.child_block_number do
      {_, child_block_number} =
        ask_for_block(state.child_block_number + child_block_interval, child_block, state.contract_address)

      {:ok, _} =
        :timer.send_after(Application.get_env(:omisego_watcher, :get_block_interval), self(), :check_for_new_block)

      {:noreply, %{state | child_block_number: child_block_number}}
    else
      {:ok, _} =
        :timer.send_after(Application.get_env(:omisego_watcher, :get_block_interval), self(), :check_for_new_block)

      {:noreply, state}
    end
  end
end

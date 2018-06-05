defmodule OmiseGOWatcher.BlockGetter do
  @moduledoc """
  tracking block on child chain
  """
  use GenServer
  alias OmiseGOWatcher.{UtxoDB, BlockValidator}
  alias OmiseGO.API.Block
  alias OmiseGO.Eth

  @dialyzer {:nowarn_function, get_block: 2}
  @spec get_block(pos_integer(), Eth.contract_t()) :: {:ok, Block.t()} | {:error, :get_block}
  def get_block(number, contract) do
    with {:ok, {hash, _time}} <- Eth.get_child_chain(number, contract),
         {:ok, json_block} <- OmiseGO.JSONRPC.Client.call(:get_block, %{hash: hash}) do
      {:ok, %Block{}} = BlockValidator.json_to_block(json_block, number)
    else
      _ -> {:error, :get_block}
    end
  end

  @dialyzer {:nowarn_function, get_blocks_async: 3}
  def get_blocks_async(from, to, contract) do
    blocks_numbers = :lists.seq(from, to, Application.get_env(:omisego_eth, :child_block_interval))
    blocks_numbers |> Enum.map(&Task.async(fn -> {&1, get_block(&1, contract)} end))
  end

  def consume_block(%Block{} = block) do
    _ = OmiseGOWatcher.TransactionDB.insert(block)
    _ = UtxoDB.consume_block(block)
    :ok
  end

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

  def get_current_block_number(contract) do
    {:ok, next_child_block} = OmiseGO.Eth.get_current_child_block(contract)
    child_block_interval = Application.get_env(:omisego_eth, :child_block_interval)
    child_block = next_child_block - child_block_interval
    child_block
  end

  def handle_info(:check_for_new_block, state) do
    child_block = get_current_block_number(state.contract_address)

    if child_block > state.child_block_number do
      blocks_async =
        get_blocks_async(
          state.child_block_number + Application.get_env(:omisego_eth, :child_block_interval),
          child_block,
          state.contract_address
        )

      {:ok, child_block_number} =
        blocks_async
        |> Enum.reduce({:ok, 0}, fn task, acc ->
          case acc do
            {:ok, _} ->
              {block_number, {:ok, block}} = Task.await(task)
              consume_block(block)
              {:ok, block_number}

            error ->
              {:ok, _} = Task.shutdown(task, :brutal_kill)
              error
          end
        end)

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

defmodule OmiseGOWatcher.BlockGetter do
  @moduledoc """
  tracking block on child chain
  """
  use GenServer
  alias OmiseGO.API.Block
  alias OmiseGO.Eth
  alias OmiseGOWatcher.BlockGetter.Core
  alias OmiseGOWatcher.{BlockValidator, UtxoDB}

  @spec get_block(pos_integer(), Eth.contract_t()) :: {:ok, Block.t()} | {:error, :get_block}
  def get_block(number, contract) do
    with {:ok, {hash, _time}} <- Eth.get_child_chain(number, contract),
         {:ok, json_block} <- OmiseGO.JSONRPC.Client.call(:get_block, %{hash: hash}) do
      {:ok, %Block{}} = BlockValidator.json_to_block(Map.put(json_block, "number", number))
    else
      _ -> {:error, :get_block}
    end
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
         child_block_interval <- Application.get_env(:omisego_eth, :child_block_interval),
         {:ok, _} <- :timer.send_after(0, self(), :producer) do
      {:ok, Core.init(block_number, child_block_interval)}
    end
  end

  # TODO get_height used in tests instead of an event system, remove when event system is here
  def handle_call(:get_height, _from, state) do
    {:reply, state.block_info.consume, state}
  end

  def handle_info(:producer, state) do
    new_state = run_block_get_task(state)
    {:ok, _} = :timer.send_after(2_000, self(), :producer)
    {:noreply, new_state}
  end

  def handle_info({_ref, {:got_block, {:ok, block}}}, state) do
    {new_state, blocks_to_consume} =
      state
      |> Core.add_block(block)
      |> Core.get_blocks_to_consume()

    new_state = run_block_get_task(new_state)
    _ = blocks_to_consume |> Enum.map(&consume_block/1)
    {:noreply, new_state}
  end

  def handle_info({:DOWN, _ref, :process, _pid, :normal} = _process, state) do
    {:noreply, Core.task_complited(state)}
  end

  defp run_block_get_task(state) do
    contract_address = Application.get_env(:omisego_eth, :contract_address)
    {:ok, next_child} = Eth.get_current_child_block(contract_address)

    {new_state, blocks_numbers} = Core.get_new_blocks_numbers(state, next_child)

    _task_list =
      blocks_numbers
      |> Enum.map(
        # catch result in handle_info({_ref, {:ok, block}}, state)
        # handle_info({:DOWN, _ref, :process, _pid, :normal}, state) change pull task setting (process down)
        &Task.async(fn -> {:got_block, get_block(&1, contract_address)} end)
      )

    new_state
  end
end

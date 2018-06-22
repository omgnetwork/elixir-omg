defmodule OmiseGOWatcher.BlockGetter do
  @moduledoc """
  tracking block on child chain
  """
  use GenServer
  alias OmiseGO.API.Block
  alias OmiseGO.Eth
  alias OmiseGOWatcher.BlockGetter.Core
  alias OmiseGOWatcher.UtxoDB

  @spec get_block(pos_integer()) :: {:ok, Block.t()}
  def get_block(number) do
    with {:ok, {hash, _time}} <- Eth.get_child_chain(number),
         {:ok, json_block} <- OmiseGO.JSONRPC.Client.call(:get_block, %{hash: hash}) do
      {:ok, %Block{}} = Core.decode_block(Map.put(json_block, "number", number))
    end
  end

  def consume_block(%Block{} = block) do
    # TODO add check after synch with deposit and exit
    OmiseGOWatcher.TransactionDB.insert(block)
    UtxoDB.consume_block(block)
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
    {:reply, state.last_consumed_block, state}
  end

  def get_current_block_number(contract \\ nil) do
    {:ok, next_child_block} = OmiseGO.Eth.get_current_child_block(contract)
    child_block_interval = Application.get_env(:omisego_eth, :child_block_interval)
    child_block = next_child_block - child_block_interval
    child_block
  end

  def handle_info(:producer, state) do
    {:ok, next_child} = Eth.get_current_child_block()
    {new_state, blocks_numbers} = Core.get_new_blocks_numbers(state, next_child)
    _ = run_block_get_task(blocks_numbers)

    {:ok, _} = :timer.send_after(2_000, self(), :producer)
    {:noreply, new_state}
  end

  def handle_info({_ref, {:got_block, {:ok, block}}}, state) do
    {new_state, blocks_to_consume} =
      state
      |> Core.add_block(block)
      |> Core.get_blocks_to_consume()

    {:ok, next_child} = Eth.get_current_child_block()
    {new_state, blocks_numbers} = Core.get_new_blocks_numbers(new_state, next_child)
    :ok = run_block_get_task(blocks_numbers)

    :ok = blocks_to_consume |> Enum.each(&consume_block/1)
    {:noreply, new_state}
  end

  def handle_info({:DOWN, _ref, :process, _pid, :normal} = _process, state), do: {:noreply, state}

  defp run_block_get_task(blocks_numbers) do
    blocks_numbers
    |> Enum.each(
      # captures the result in handle_info/2 with the atom: got_block
      &Task.async(fn -> {:got_block, get_block(&1)} end)
    )
  end
end

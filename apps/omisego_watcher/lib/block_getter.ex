defmodule OmiseGOWatcher.BlockGetter do
  @moduledoc """
  Checking if there are new block from child chain on ethereum.
  Checking if Block from child chain is valid
  Download new block from child chain and update State, TransactionDB, UtxoDB.
  """
  use GenServer
  alias OmiseGO.API.{Block, State}
  alias OmiseGO.Eth
  alias OmiseGOWatcher.BlockGetter.Core
  alias OmiseGOWatcher.UtxoDB
  alias OmiseGO.API.BlockQueue

  @spec get_block(pos_integer()) :: {:ok, Block.t()}
  def get_block(number) do
    with {:ok, {hash, _time}} <- Eth.get_child_chain(number),
         {:ok, json_block} <- OmiseGO.JSONRPC.Client.call(:get_block, %{hash: hash}) do
      Core.decode_block(Map.put(json_block, "number", number))
    end
  end

  def consume_block(%Block{} = block) do
    # TODO add check after synch with deposit and exit
    _ = OmiseGOWatcher.TransactionDB.insert(block)
    _ = UtxoDB.consume_block(block)

    child_block_interval = BlockQueue.child_block_interval()

    {event_triggers} = State.close_block(child_block_interval)
    # TODO pass event_triggers to Eventer

    :ok
  end

  def start_link(_args) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(_opts) do
    {:ok, block_number} = OmiseGO.DB.child_top_block_number()
    child_block_interval = Application.get_env(:omisego_eth, :child_block_interval)
    {:ok, _} = :timer.send_after(0, self(), :producer)

    {:ok, Core.init(block_number, child_block_interval)}
  end

  # TODO get_height used in tests instead of an event system, remove when event system is here
  def handle_call(:get_height, _from, state) do
    {:reply, state.last_consumed_block, state}
  end

  def handle_info(:producer, state) do
    {:ok, next_child} = Eth.get_current_child_block()
    {new_state, blocks_numbers} = Core.get_new_blocks_numbers(state, next_child)
    :ok = run_block_get_task(blocks_numbers)

    {:ok, _} = :timer.send_after(2_000, self(), :producer)
    {:noreply, new_state}
  end

  def handle_info({_ref, {:got_block, {:ok, %Block{} = block}}}, state) do
    {:ok, state} = Core.add_block(state, block)
    {new_state, blocks_to_consume} = Core.get_blocks_to_consume(state)

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

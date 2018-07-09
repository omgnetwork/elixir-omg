defmodule OmiseGOWatcher.BlockGetter do
  @moduledoc """
  Checking if there are new block from child chain on ethereum.
  Checking if Block from child chain is valid
  Download new block from child chain and update State, TransactionDB, UtxoDB.
  """
  use GenServer
  alias OmiseGO.API.Block
  alias OmiseGO.API.State.Transaction.Recovered
  alias OmiseGO.Eth
  alias OmiseGOWatcher.BlockGetter.Core
  alias OmiseGOWatcher.UtxoDB

  require Logger

  @spec get_block(pos_integer()) :: {:ok, Block.t()}
  def get_block(number) do
    with {:ok, {hash, _time}} <- Eth.get_child_chain(number),
         {:ok, json_block} <- OmiseGO.JSONRPC.Client.call(:get_block, %{hash: hash}) do
      Core.decode_validate_block(Map.put(json_block, "number", number))
    end
  end

  def consume_block(%Block{transactions: transactions} = block) do
    # TODO add check in UtxoDB after deposit handle correctly
    state_exec =
      for tx <- transactions do
        with {:ok, recover_tx} <- Recovered.recover_from(tx), do: OmiseGO.API.State.exec(recover_tx)
      end

    with nil <- Enum.find(state_exec, &(!match?({:ok, _, _, _}, &1))),
         response <- OmiseGOWatcher.TransactionDB.insert(block),
         nil <- Enum.find(response, &(!match?({:ok, _}, &1))),
         _ <- UtxoDB.consume_block(block),
         do: :ok
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

  def handle_info({_ref, {:got_block, {:ok, %Block{number: blknum, transactions: txs, hash: hash} = block}}}, state) do
    {:ok, state} = Core.add_block(state, block)
    {new_state, blocks_to_consume} = Core.get_blocks_to_consume(state)

    {:ok, next_child} = Eth.get_current_child_block()
    {new_state, blocks_numbers} = Core.get_new_blocks_numbers(new_state, next_child)

    _ =
      Logger.info(fn ->
        "Received block \##{inspect(blknum)} #{hash |> Base.encode16() |> Binary.drop(-48)}... with #{length(txs)} txs." <>
          " Child chain seen at block \##{next_child}. Getting blocks #{inspect(blocks_numbers)}"
      end)

    :ok = run_block_get_task(blocks_numbers)

    :ok =
      blocks_to_consume
      |> Enum.each(&(:ok = consume_block(&1)))

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

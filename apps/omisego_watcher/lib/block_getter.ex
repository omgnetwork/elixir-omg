defmodule OmiseGOWatcher.BlockGetter do
  @moduledoc """
  Checking if there are new block from child chain on ethereum.
  Checking if Block from child chain is valid
  Download new block from child chain and update State, TransactionDB, UtxoDB.
  Manage simultaneous getting and stateless-processing of blocks and manage the results of that
  Detects byzantine situations like BlockWithholding and InvalidBlock and passes this events to Eventer
  """
  alias OmiseGO.API.Block
  alias OmiseGO.API.RootChainCoordinator
  alias OmiseGO.Eth
  alias OmiseGOWatcher.BlockGetter.Core
  alias OmiseGOWatcher.Eventer
  alias OmiseGOWatcher.UtxoDB

  use GenServer
  use OmiseGO.API.LoggerExt

  @spec get_block(pos_integer()) ::
          {:ok, Block.t() | Core.PotentialWithholding.t()} | {:error, Core.block_error(), binary(), pos_integer()}
  def get_block(requested_number) do
    {:ok, {requested_hash, _time}} = Eth.get_child_chain(requested_number)
    rpc_response = OmiseGO.JSONRPC.Client.call(:get_block, %{hash: requested_hash})
    Core.validate_get_block_response(rpc_response, requested_hash, requested_number, :os.system_time(:millisecond))
  end

  def handle_cast(
        {:consume_block, %{transactions: transactions, number: blknum, zero_fee_requirements: fees} = block, block_rootchain_height},
        state
      ) do
    state_exec_results = for tx <- transactions, do: OmiseGO.API.State.exec(tx, fees)

    {continue, events} = Core.check_tx_executions(state_exec_results, block)

    Eventer.emit_events(events)

    with :ok <- continue do
      response = OmiseGOWatcher.TransactionDB.update_with(block)
      nil = Enum.find(response, &(!match?({:ok, _}, &1)))
      _ = UtxoDB.update_with(block)
      _ = Logger.info(fn -> "Consumed block \##{inspect(blknum)}" end)
      {:ok, next_child} = Eth.get_current_child_block()
      {new_state, blocks_numbers} = Core.get_new_blocks_numbers(state, next_child)
      :ok = run_block_get_task(blocks_numbers)

      _ =
        Logger.info(fn ->
          "Child chain seen at block \##{inspect(next_child)}. Getting blocks #{inspect(blocks_numbers)}"
        end)

      child_block_interval = Application.get_env(:omisego_eth, :child_block_interval)

      :ok = OmiseGO.API.State.close_block(child_block_interval, block_rootchain_height)

      new_state = Core.block_consumed(new_state, blknum)
      {:noreply, new_state}
    else
      {:needs_stopping, reason} ->
        _ = Logger.error(fn -> "Stopping BlockGetter becasue of #{inspect(reason)}" end)
        {:stop, :shutdown, state}
    end
  end

  def start_link(_args) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(_opts) do
    {:ok, block_number} = OmiseGO.DB.child_top_block_number()
    child_block_interval = Application.get_env(:omisego_eth, :child_block_interval)
    {:ok, _} = :timer.send_after(0, self(), :producer)

    {:ok, deployment_height} = Eth.get_root_deployment_height()
    :ok = RootChainCoordinator.set_service_height(deployment_height, :block_getter)

    {:ok, Core.init(block_number, child_block_interval)}
  end

  # TODO get_height used in tests instead of an event system, remove when event system is here
  def handle_call(:get_height, _from, state) do
    {:reply, state.last_consumed_block, state}
  end

  @spec handle_info(
          :producer
          | {reference(), {:got_block, {:ok, map}}}
          | {reference(), {:got_block, {:error, Core.block_error()}}}
          | {:DOWN, reference(), :process, pid, :normal},
          Core.t()
        ) :: {:noreply, Core.t()} | {:stop, :normal, Core.t()}
  def handle_info(msg, state)

  def handle_info(:producer, state) do
    {:ok, next_child} = Eth.get_current_child_block()

    {new_state, blocks_numbers} = Core.get_new_blocks_numbers(state, next_child)

    _ =
      Logger.info(fn ->
        "Child chain seen at block \##{inspect(next_child)}. Getting blocks #{inspect(blocks_numbers)}"
      end)

    :ok = run_block_get_task(blocks_numbers)

    {:ok, _} = :timer.send_after(2_000, self(), :producer)
    {:noreply, new_state}
  end

  def handle_info({_ref, {:got_block, response}}, state) do
    # 1/ process the block that arrived and consume
    {continue, new_state, events} = Core.got_block(state, response)

    Eventer.emit_events(events)

    with :ok <- continue do
      {:noreply, new_state}
    else
      {:needs_stopping, reason} ->
        _ = Logger.error(fn -> "Stopping BlockGetter becasue of #{inspect(reason)}" end)
        {:stop, :shutdown, state}
    end
  end

  def handle_info({:DOWN, _ref, :process, _pid, :normal} = _process, state), do: {:noreply, state}

  def handle_info(:sync, state) do
    case RootChainCoordinator.get_height() do
      {:sync, next_synced_height} ->
        state =
          state
          |> set_blknums_for_synced_height(next_synced_height)
          |> consume_blocks_from_height(next_synced_height)

        {:noreply, state}
      :nosync ->
        {:noreply, state}
    end
  end

  defp set_blknums_for_synced_height(state, next_synced_height) do
    if Core.has_block_consume_batch?(state) do
      state
    else
      {:ok, submissions} = Eth.get_block_submissions(state.synced_height, next_synced_height)
      Core.set_block_consume_batch(state, submissions)
    end
  end

  defp consume_blocks_from_height(state, next_synced_height) do
    case Core.consume_blocks(state) do
      {:blocks_consumed, state} ->
        RootChainCoordinator.set_service_height(next_synced_height, :block_getter)
        Core.update_synced_height(state, next_synced_height)
      {:blocks_to_consume, blocks_to_consume, state} ->
        Enum.each(blocks_to_consume, fn {block, eth_height} -> GenServer.cast(__MODULE__, {:consume_block, block, eth_height}) end)
        state
      {_, state} -> state
    end
  end

  defp run_block_get_task(blocks_numbers) do
    blocks_numbers
    |> Enum.each(
      # captures the result in handle_info/2 with the atom: got_block
      &Task.async(fn -> {:got_block, get_block(&1)} end)
    )
  end
end

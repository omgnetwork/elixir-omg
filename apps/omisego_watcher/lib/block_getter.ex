defmodule OmiseGOWatcher.BlockGetter do
  @moduledoc """
  Checking if there are new block from child chain on ethereum.
  Checking if Block from child chain is valid
  Download new block from child chain and update State, TransactionDB, UtxoDB.
  Manage simultaneous getting and stateless-processing of blocks and manage the results of that
  """
  alias OmiseGO.API.Block
  alias OmiseGO.Eth
  alias OmiseGOWatcher.BlockGetter.Core
  alias OmiseGOWatcher.Eventer
  alias OmiseGOWatcher.Eventer.Event
  alias OmiseGOWatcher.UtxoDB

  use GenServer
  use OmiseGO.API.LoggerExt

  @spec get_block(pos_integer()) ::
          {:ok, Block.t() | Core.PotentialWithholding.t()} | {:error, Core.block_error(), binary(), pos_integer()}
  def get_block(requested_number) do
    {:ok, {requested_hash, _time}} = Eth.get_child_chain(requested_number)
    rpc_response = OmiseGO.JSONRPC.Client.call(:get_block, %{hash: requested_hash})

    case Core.decode_validate_block(rpc_response, requested_hash, requested_number) do
      {:ok, map} ->
        {:ok, map}

      {:error, error_type} ->
        {:error, error_type, requested_hash, requested_number}
    end
  end

  defp consume_blocks(blocks) do
    Enum.each(&(:ok = consume_block(&1)))
    state_consume_blocks = for block <- blocks, do: consume_block(block)

  end

  defp consume_block(%{transactions: transactions, number: blknum, zero_fee_requirements: fees} = block) do
    # TODO add check in UtxoDB after deposit handle correctly
    state_exec = for tx <- transactions, do: OmiseGO.API.State.exec(tx, fees)

    OmiseGO.API.State.close_block(Application.get_env(:omisego_eth, :child_block_interval))

    with events <- Core.check_tx_executions(state_exec),
         response <- OmiseGOWatcher.TransactionDB.update_with(block),
         nil <- Enum.find(response, &(!match?({:ok, _}, &1))),
         _ <- UtxoDB.update_with(block),
         _ = Logger.info(fn -> "Consumed block \##{inspect(blknum)}" end),
         do: {:ok, events}
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
    {continue, new_state, blocks_to_consume, events} = Core.got_block(state, response)
    Eventer.emit_events(events)
    consume_status = consume_blocks(blocks_to_consume)

    with :ok <- continue,
         :ok <- consume_status do
      # the next_child thing
      {:noreply, new_status}
    else
      {:needs_stopping, reason} ->
        # log
        {:stop, :normal, state}
    end

#    {continue, new_state, blocks_to_consume, events} = Core.got_block(state,response)
#    Enum.each(events, emit_event)
#    consume_status = consume_blocks(blocks_to_consume) # this Enum.maps with consume_block and if anything isn't :ok returns that


#    case event do
#      nil ->
#        {:ok, %{number: blknum, transactions: _txs, hash: hash}} = response
#
#        :ok =
#          Enum.each(
#            blocks_to_consume,
#            &(:ok =
#                case consume_block(&1) do
#                  :ok ->
#                    :ok
#
#                  {:error, error_type} ->
#                    event = %Event.InvalidBlock{
#                      error_type: error_type,
#                      hash: hash,
#                      number: blknum
#                    }
#
#                    Eventer.emit_events([event])
#                    _ = Logger.error(fn -> "Stopping BlockGetter becasue of #{inspect(event)}" end)
#                    {:error, error_type}
#                end)
#          )
#
#        # 2/ try continuing the getting process immediately
#        {:ok, next_child} = Eth.get_current_child_block()
#
#        {new_state, blocks_numbers} = Core.get_new_blocks_numbers(new_state, next_child)
#
#        :ok = run_block_get_task(blocks_numbers)
#        {:noreply, new_state}
#
#      _ ->
#        Eventer.emit_events([event])
#        _ = Logger.error(fn -> "Stopping BlockGetter becasue of #{inspect(event)}" end)
#        {:stop, :normal, state}
#    end
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

defmodule OmiseGO.API.State do
  @moduledoc """
  Imperative shell for the state.
  The state meant here is the state of the ledger (UTXO set), that determines spendability of coins and forms blocks.
  All spend transactions, deposits and exits should sync on this for validity of moving funds.
  """

  alias OmiseGO.API.BlockQueue
  alias OmiseGO.API.FreshBlocks
  alias OmiseGO.API.State.Core
  alias OmiseGO.DB
  alias OmiseGO.Eth
  alias OmiseGOWatcher.Eventer

  require Logger

  ### Client

  def start_link(_args) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def exec(tx, input_fees) do
    GenServer.call(__MODULE__, {:exec, tx, input_fees})
  end

  def form_block(child_block_interval) do
    GenServer.cast(__MODULE__, {:form_block, child_block_interval})
  end

  def close_block(child_block_interval) do
    GenServer.cast(__MODULE__, {:close_block, child_block_interval})
  end

  def deposit(deposits_enc) do
    deposits = Enum.map(deposits_enc, &Core.decode_deposit/1)
    GenServer.call(__MODULE__, {:deposits, deposits})
  end

  def exit_utxos(utxos) do
    GenServer.call(__MODULE__, {:exit_utxos, utxos})
  end

  def exit_if_not_spent(utxo) do
    GenServer.call(__MODULE__, {:exit_not_spent_utxo, utxo})
  end

  @spec utxo_exists(%{blknum: number, txindex: number, oindex: number}) :: :utxo_exists | :utxo_does_not_exist
  def utxo_exists(utxo) do
    GenServer.call(__MODULE__, {:utxo_exists, utxo})
  end

  @spec get_current_child_block_height :: pos_integer
  def get_current_child_block_height do
    GenServer.call(__MODULE__, :get_current_height)
  end

  ### Server

  use GenServer

  @doc """
  Start processing state using the database entries
  """
  def init(:ok) do
    {:ok, height_query_result} = DB.child_top_block_number()
    {:ok, last_deposit_query_result} = DB.last_deposit_height()
    {:ok, utxos_query_result} = DB.utxos()

    {
      :ok,
      Core.extract_initial_state(
        utxos_query_result,
        height_query_result,
        last_deposit_query_result,
        BlockQueue.child_block_interval()
      )
    }
  end

  @doc """
  Checks (stateful validity) and executes a spend transaction. Assuming stateless validity!
  """
  def handle_call({:exec, tx, fees}, _from, state) do
    {tx_result, new_state} = Core.exec(tx, fees, state)
    {:reply, tx_result, new_state}
  end

  @doc """
  Includes a deposit done on the root chain contract (see above - not sure about this)
  """
  def handle_call({:deposits, deposits}, _from, state) do
    # TODO event_triggers is ignored because Eventer is moving to Watcher - tidy this
    {_event_triggers, db_updates, new_state} = Core.deposit(deposits, state)

    # GenServer.call
    :ok = DB.multi_update(db_updates)
    {:reply, :ok, new_state}
  end

  @doc """
  Exits (spends) utxos on child chain
  """
  def handle_call({:exit_utxos, utxos}, _from, state) do
    do_exit_utxos(utxos, state)
  end

  @doc """
  Exits (spends) utxos on child chain, explicitly signals if utxo has already been spent
  """
  def handle_call({:exit_not_spent_utxo, utxo}, _from, state) do
    with :utxo_exists <- Core.utxo_exists(utxo, state) do
      do_exit_utxos([utxo], state)
    else
      :utxo_does_not_exist -> {:reply, :utxo_does_not_exist, state}
    end
  end

  @doc """
  Tells if utxo exists
  """
  def handle_call({:utxo_exists, utxo}, _from, state) do
    {:reply, Core.utxo_exists(utxo, state), state}
  end

  @doc """
  Gets the current block's height
  """
  def handle_call(:get_current_height, _from, state) do
    {:reply, Core.get_current_child_block_height(state), state}
  end

  @doc """
    Wraps up accumulated transactions submissionsinto a block, triggers db update and emits
    events to Eventer
  """
  def handle_cast({:close_block, child_block_interval}, state) do
    {_core_form_block_duration, core_form_block_result} =
      :timer.tc(fn -> Core.form_block(state, child_block_interval) end)

    {:ok, {block, event_triggers, db_updates, new_state}} = core_form_block_result

    :ok = DB.multi_update(db_updates)

    block_submission = Eth.get_block_submission(block.hash)

    event_triggers =
      Enum.map(event_triggers, fn event_trigger ->
        event_trigger
        |> Map.put(:child_block_hash, block.hash)
        |> Map.put(:child_blknum, block.number)
        |> Map.put(:submited_at_ethheight, block_submission && block_submission.eth_height)
      end)

    Eventer.notify(event_triggers)

    {:noreply, new_state}
  end

  @doc """
  Wraps up accumulated transactions into a block, triggers db update,
  publishes block and enqueues for submission
  """
  def handle_cast({:form_block, child_block_interval}, state) do
    _ = Logger.debug(fn -> "Forming new block..." end)
    {duration, result} = :timer.tc(fn -> do_form_block(child_block_interval, state) end)
    _ = Logger.info(fn -> "Done forming block in #{round(duration / 1000)} ms" end)
    result
  end

  defp do_form_block(child_block_interval, state) do
    # TODO event_triggers is ignored because Eventer is moving to Watcher - tidy this
    {core_form_block_duration, core_form_block_result} =
      :timer.tc(fn -> Core.form_block(state, child_block_interval) end)

    {:ok, {block, _event_triggers, db_updates, new_state}} = core_form_block_result

    _ =
      Logger.info(fn ->
        "Calculations for forming block #{block.number} done in #{round(core_form_block_duration / 1000)} ms"
      end)

    :ok = DB.multi_update(db_updates)
    :ok = FreshBlocks.push(block)
    :ok = BlockQueue.enqueue_block(block.hash, block.number)

    {:noreply, new_state}
  end

  defp do_exit_utxos(utxos, state) do
    # TODO event_triggers is ignored because Eventer is moving to Watcher - tidy this
    {_event_triggers, db_updates, new_state} = Core.exit_utxos(utxos, state)

    # GenServer.call
    :ok = DB.multi_update(db_updates)
    {:reply, :ok, new_state}
  end
end

defmodule OmiseGO.API.State do
  @moduledoc """
  Imperative shell for the state
  """
  # TODO: file skipped in coveralls.json - this should be undone, when some integration tests land for this

  alias OmiseGO.API.State.Core
  alias OmiseGO.API.Eventer
  alias OmiseGO.API.FreshBlocks
  alias OmiseGO.API.BlockQueue
  alias OmiseGO.DB

  ### Client

  def start_link(_args) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def exec(tx) do
    GenServer.call(__MODULE__, {:exec, tx})
  end

  def form_block(block_num_to_form, next_block_num_to_form) do
    GenServer.call(__MODULE__, {:form_block, block_num_to_form, next_block_num_to_form})
  end

  def deposit(deposits_enc) do
    deposits = Enum.map(deposits_enc, &Core.decode_deposit/1)
    GenServer.call(__MODULE__, {:deposits, deposits})
  end

  def exit_utxos(utxos) do
    GenServer.call(__MODULE__, {:exit_utxos, utxos})
  end

  ### Server

  use GenServer

  @doc """
  Start processing state using the database entries
  """
  def init(:ok) do
    with {:ok, height_query_result} <- DB.child_top_block_number(),
         {:ok, last_deposit_query_result} <- DB.last_deposit_height(),
         {:ok, utxos_query_result} <- DB.utxos() do
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
  end

  @doc """
  Checks (stateful validity) and executes a spend transaction. Assuming stateless validity!
  """
  def handle_call({:exec, tx}, _from, state) do
    {tx_result, new_state} = Core.exec(tx, state)
    {:reply, tx_result, new_state}
  end

  @doc """
  Includes a deposit done on the root chain contract (see above - not sure about this)
  """
  def handle_call({:deposits, deposits}, _from, state) do
    {event_triggers, db_updates, new_state} = Core.deposit(deposits, state)
    # GenServer.cast
    Eventer.notify(event_triggers)
    # GenServer.call
    :ok = DB.multi_update(db_updates)
    {:reply, :ok, new_state}
  end

  @doc """
  Exits (spends) utxos on child chain
  """
  def handle_call({:exit_utxos, utxos}, _from, state) do
    {event_triggers, db_updates, new_state} = Core.exit_utxos(utxos, state)
    # GenServer.cast
    Eventer.notify(event_triggers)
    # GenServer.call
    :ok = DB.multi_update(db_updates)
    {:reply, :ok, new_state}
  end

  @doc """
  Wraps up accumulated transactions into a block, triggers events, triggers db update, returns block hash
  """
  def handle_call({:form_block, block_num_to_form, next_block_num_to_form}, _from, state) do
    result = Core.form_block(state, block_num_to_form, next_block_num_to_form)
    with {:ok, {block, event_triggers, db_updates, new_state}} <- result,
         :ok <- DB.multi_update(db_updates) do
      Eventer.notify(event_triggers)
      :ok = FreshBlocks.push(block)
      {:reply, {:ok, block.hash}, new_state}
    end
 end
end

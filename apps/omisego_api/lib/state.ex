defmodule OmiseGO.API.State do
  @moduledoc """
  Imperative shell for the state
  """
  # TODO: file skipped in coveralls.json - this should be undone, when some integration tests land for this

  ### Client

  def start_link do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def exec(tx) do
    GenServer.call(__MODULE__, {:exec, tx})
  end

  def form_block(current_block_num, next_block_num) do
    GenServer.call(__MODULE__, {:form_block, current_block_num, next_block_num})
  end

  def deposit(owner, amount) do
    GenServer.call(__MODULE__, {:deposit, owner, amount})
  end

  ### Server

  use GenServer

  alias OmiseGO.API.State.Core
  alias OmiseGO.API.Eventer
  alias OmiseGO.DB

  @doc """
  Start processing state using the database entries
  """
  def init(:ok) do
    with {:ok, utxos_query_result} <- DB.utxos(),
         {:ok, height_query_result} <- DB.child_top_block_number(),
         do: {:ok, Core.extract_initial_state(utxos_query_result, height_query_result)}
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
  def handle_call({:deposit, owner, amount}, _from, state) do
    {event_triggers, db_updates, new_state} = Core.deposit(owner, amount, state)
    # GenServer.cast
    Eventer.notify(event_triggers)
    # GenServer.call
    :ok = DB.multi_update(db_updates)
    {:reply, :ok, new_state}
  end

  @doc """
  Wraps up accumulated transactions into a block, triggers events, triggers db update, returns block hash
  """
  def handle_call({:form_block, current_block_num, next_block_num}, _from, state) do
   case Core.form_block(state, current_block_num, next_block_num) do
     {:error, reason} -> {:reply, {:error, reason}, state}
     {:ok, {block, event_triggers, db_updates, new_state}} ->
       # GenServer.cast
       Eventer.notify(event_triggers)
       # GenServer.call
       :ok = DB.multi_update(db_updates)
       {:reply, {:ok, block.hash}, new_state}
   end
 end
end

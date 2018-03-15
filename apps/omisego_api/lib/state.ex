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

  def form_block do
    GenServer.call(__MODULE__, :form_block)
  end

  # NOTE: totally not sure about the argumets here and coordination child vs root
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
    with db_queries <- Core.get_state_fetching_query(),
         {:ok, query_result} <- DB.multi_get(db_queries),
         do: {:ok, Core.extract_initial_state(query_result)}
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
  def handle_call(:form_block, _from, state) do
    {block, event_triggers, db_updates, new_state} = Core.form_block(state)
    # GenServer.cast
    Eventer.notify(event_triggers)
    # GenServer.call
    :ok = DB.multi_update(db_updates)
    {:reply, {:ok, block.hash}, new_state}
  end
end

defmodule OmiseGO.State do

  ### Client

  def start_link() do
    GenServer.start_link(__MODULE__, :ok, __MODULE__)
  end

  def exec(tx) do
    GenServer.call(__MODULE__{:exec, tx})
  end

  def form_block() do
    GenServer.cast(__MODULE__, {:form_block})
  end

  def deposit(owner, amount, height) do # NOTE: totally not sure about the argumets here and coordination child vs root
    GenServer.call(__MODULE__, {:deposit, owner, amount, height})
  end

  ### Server

  use GenServer

  def get_state_fetching_query() do
    ["/utxos/*", "/height"] # whateva
  end

  def extract_initial_state(kvs) do
    # decode kvs to sensible stuff
    {height, utxos}
  end

  def init(:ok) do
    with db_queries <- Core.get_state_fetching_query(),
         {:ok, query_result} <- DB.multi_get(db_queries),
         do: Core.extract_initial_state(query_result)
  end

  def handle_call({:exec, tx}, _from, state) do
    {tx_result, new_state} = Core.exec(tx, state)
    {:reply, tx_result, new_state}
  end

  def handle_cast({:form_block}, _from, state) do
    {block, event_triggers, db_updates, new_state} = Core.form_block(state)
    Eventer.notify(event_triggers) # GenServer.cast
    DB.multi_update(db_updates) # GenServer.cast
    BlockQueue.push_block(block) # GenServer.cast
    {:noreply, :ok, new_state}
  end

  def handle_call({:deposit, owner, amount, height}, _from, state) do
    {block, event_triggers, db_updates, new_state} = Core.deposit(owner, amount, height, state)
    Eventer.notify(event_triggers) # GenServer.cast
    DB.multi_update(db_updates) # GenServer.cast
    BlockQueue.push_block(block) # GenServer.cast
    {:reply, :ok, new_state}
  end

  defmodule Core do
    defstruct [:height, tx_index: 0, :utxos, pending_txs: []]

    def get_state_fetching_query() do
      # some form of coding what we need to start up state
      db_queries
    end

    def extract_initial_state(query_result) do
      # extract height and utxos from query result
      %__MODULE__.Core{height: height, utxos: utxos}
    end

    def exec(tx, state) do
      # stateful validity
      # state update
      {tx_result, new_state}
    end

    def form_block(state)
      # block generation
      # generating event triggers
      # generate requests to persistence
      # drop pending txs from state, update height etc.
      {block, event_triggers, db_updates, new_state}
    end

    def deposit(owner, amount, height, state) do
      # TODO: no idea yet
    end

  end
end

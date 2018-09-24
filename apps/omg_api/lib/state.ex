# Copyright 2018 OmiseGO Pte Ltd
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

defmodule OMG.API.State do
  @moduledoc """
  Imperative shell for the state.
  The state meant here is the state of the ledger (UTXO set), that determines spendability of coins and forms blocks.
  All spend transactions, deposits and exits should sync on this for validity of moving funds.
  """
  alias OMG.API.Block
  alias OMG.API.BlockQueue
  alias OMG.API.EventerAPI
  alias OMG.API.FreshBlocks
  alias OMG.API.State.Core
  alias OMG.API.State.Transaction
  alias OMG.DB
  alias OMG.Eth

  use OMG.API.LoggerExt

  ### Client

  def start_link(_args) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @spec exec(tx :: %Transaction.Recovered{}, fees :: map()) ::
          {:ok, {Transaction.Recovered.signed_tx_hash_t(), pos_integer, pos_integer}}
          | {:error, Core.exec_error()}
  def exec(tx, input_fees) do
    GenServer.call(__MODULE__, {:exec, tx, input_fees})
  end

  def form_block do
    GenServer.cast(__MODULE__, :form_block)
  end

  def close_block(eth_height) do
    GenServer.call(__MODULE__, {:close_block, eth_height})
  end

  @spec deposit(deposits :: [Core.deposit()]) :: :ok
  def deposit(deposits) do
    GenServer.call(__MODULE__, {:deposits, deposits})
  end

  def exit_utxos(utxos) do
    GenServer.call(__MODULE__, {:exit_utxos, utxos})
  end

  def exit_if_not_spent(utxo) do
    GenServer.call(__MODULE__, {:exit_not_spent_utxo, utxo})
  end

  @spec utxo_exists?(Core.exit_t()) :: boolean()
  def utxo_exists?(utxo) do
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
    {:ok, last_deposit_query_result} = DB.last_deposit_child_blknum()
    {:ok, utxos_query_result} = DB.utxos()
    {:ok, child_block_interval} = Eth.RootChain.get_child_block_interval()

    with {:ok, _data} = result <-
           Core.extract_initial_state(
             utxos_query_result,
             height_query_result,
             last_deposit_query_result,
             child_block_interval
           ) do
      _ =
        Logger.info(fn ->
          "Started State, height: #{height_query_result}, deposit height: #{last_deposit_query_result}"
        end)

      result
    else
      {:error, reason} = error when reason in [:top_block_number_not_found, :last_deposit_not_found] ->
        _ = Logger.error(fn -> "It seems that Child chain database is not initialized. Check README.md" end)
        error

      other ->
        other
    end
  end

  @doc """
  Checks (stateful validity) and executes a spend transaction. Assuming stateless validity!
  """
  def handle_call({:exec, tx, fees}, _from, state) do
    case Core.exec(tx, fees, state) do
      {:ok, tx_result, new_state} ->
        {:reply, {:ok, tx_result}, new_state}

      {tx_result, new_state} ->
        {:reply, tx_result, new_state}
    end
  end

  @doc """
  Includes a deposit done on the root chain contract (see above - not sure about this)
  """
  def handle_call({:deposits, deposits}, _from, state) do
    {:ok, {event_triggers, db_updates}, new_state} = Core.deposit(deposits, state)

    # GenServer.call
    :ok = DB.multi_update(db_updates)

    EventerAPI.emit_events(event_triggers)

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
    if Core.utxo_exists?(utxo, state) do
      do_exit_utxos([utxo], state)
    else
      {:reply, :utxo_does_not_exist, state}
    end
  end

  @doc """
  Tells if utxo exists
  """
  def handle_call({:utxo_exists, utxo}, _from, state) do
    {:reply, Core.utxo_exists?(utxo, state), state}
  end

  @doc """
  Gets the current block's height
  """
  def handle_call(:get_current_height, _from, state) do
    {:reply, Core.get_current_child_block_height(state), state}
  end

  @doc """
  Works exactly like handle_cast(:form_block) but is synchronous

  Also, eth_height given is the Ethereum chain height where the block being closed got submitted, to be used with events.

  Someday, one might want to skip some of computations done (like calculating the root hash, which is scrapped)
  """
  def handle_call({:close_block, eth_height}, _from, state) do
    {duration, {result, new_state}} = :timer.tc(fn -> do_form_block(state, eth_height) end)
    _ = Logger.debug(fn -> "Closing block done in #{inspect(round(duration / 1000))} ms" end)
    {:reply, result, new_state}
  end

  @doc """
  Wraps up accumulated transactions submissions into a block, triggers db update and:
   - emits events to Eventer (if it is running, i.e. in Watcher).
   - pushes the new block into the respective service (if it is running, i.e. in Child Chain server)
   - enqueues the new block for submission to BlockQueue (if it is running, i.e. in Child Chain server)
  """
  def handle_cast(:form_block, state) do
    _ = Logger.debug(fn -> "Forming new block..." end)
    {duration, {_result, new_state}} = :timer.tc(fn -> do_form_block(state) end)
    _ = Logger.info(fn -> "Forming block done in #{inspect(round(duration / 1000))} ms" end)
    {:noreply, new_state}
  end

  defp do_form_block(state, eth_height \\ nil) do
    {:ok, child_block_interval} = Eth.RootChain.get_child_block_interval()

    {core_form_block_duration, {:ok, {%Block{number: blknum} = block, event_triggers, db_updates}, new_state}} =
      :timer.tc(fn -> Core.form_block(child_block_interval, state) end)

    _ =
      Logger.info(fn ->
        "Calculations for forming block number #{inspect(blknum)} done in #{
          inspect(round(core_form_block_duration / 1000))
        } ms"
      end)

    :ok = DB.multi_update(db_updates)

    ### casts, note these are no-ops if given processes are turned off
    FreshBlocks.push(block)
    BlockQueue.enqueue_block(block.hash, block.number)
    # enrich the event triggers with the ethereum height supplied
    event_triggers
    |> Enum.map(&Map.put(&1, :submited_at_ethheight, eth_height))
    |> EventerAPI.emit_events()

    ###

    {:ok, new_state}
  end

  defp do_exit_utxos(utxos, state) do
    {:ok, {_event_triggers, db_updates}, new_state} = Core.exit_utxos(utxos, state)

    _ =
      Logger.debug(fn ->
        utxos =
          db_updates
          |> Enum.map(fn {:delete, :utxo, utxo} -> "#{inspect(utxo)}" end)

        "UTXOS: " <> Enum.join(utxos, ", ")
      end)

    # GenServer.call
    :ok = DB.multi_update(db_updates)
    {:reply, :ok, new_state}
  end
end

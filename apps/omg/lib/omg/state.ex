# Copyright 2019 OmiseGO Pte Ltd
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

defmodule OMG.State do
  @moduledoc """
  Imperative shell - a GenServer serving the ledger, for functional core and more info see `OMG.State.Core`.
  """

  alias OMG.Block
  alias OMG.DB
  alias OMG.Eth
  alias OMG.Fees
  alias OMG.Recorder
  alias OMG.State.Core
  alias OMG.State.Transaction
  alias OMG.Utxo

  use GenServer
  use OMG.Utils.Metrics
  use OMG.Utils.LoggerExt

  @type exec_error :: Core.exec_error()

  ### Client

  def start_link(_args) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @decorate measure_event()
  @spec exec(tx :: Transaction.Recovered.t(), fees :: Fees.fee_t()) ::
          {:ok, {Transaction.tx_hash(), pos_integer, non_neg_integer}}
          | {:error, exec_error()}
  def exec(tx, input_fees) do
    GenServer.call(__MODULE__, {:exec, tx, input_fees})
  end

  def form_block do
    GenServer.cast(__MODULE__, :form_block)
  end

  @decorate measure_event()
  @spec close_block(pos_integer) :: {:ok, list(Core.db_update())}
  def close_block(eth_height) do
    GenServer.call(__MODULE__, {:close_block, eth_height})
  end

  @decorate measure_event()
  @spec deposit(deposits :: [Core.deposit()]) :: {:ok, list(Core.db_update())}
  def deposit(deposits) do
    GenServer.call(__MODULE__, {:deposits, deposits})
  end

  @decorate measure_event()
  @spec exit_utxos(utxos :: Core.exiting_utxos_t()) ::
          {:ok, list(Core.db_update()), Core.validities_t()}
  def exit_utxos(utxos) do
    GenServer.call(__MODULE__, {:exit_utxos, utxos})
  end

  @decorate measure_event()
  @spec utxo_exists?(Utxo.Position.t()) :: boolean()
  def utxo_exists?(utxo) do
    GenServer.call(__MODULE__, {:utxo_exists, utxo})
  end

  @decorate measure_event()
  @spec get_status :: {non_neg_integer(), boolean()}
  def get_status do
    GenServer.call(__MODULE__, :get_status)
  end

  ### Server

  @doc """
  Start processing state using the database entries
  """
  def init(:ok) do
    # Get utxos() is essential for the State and Blockgetter. And it takes a while. TODO - measure it!
    # Our approach is simply blocking the supervision boot tree
    # until we've processed history.
    {:ok, DB.utxos(), {:continue, :setup}}
  end

  def handle_continue(:setup, {:ok, utxos_query_result}) do
    {:ok, height_query_result} = DB.get_single_value(:child_top_block_number)
    {:ok, last_deposit_query_result} = DB.get_single_value(:last_deposit_child_blknum)
    {:ok, child_block_interval} = Eth.RootChain.get_child_block_interval()

    {:ok, state} =
      with {:ok, _data} = result <-
             Core.extract_initial_state(
               utxos_query_result,
               height_query_result,
               last_deposit_query_result,
               child_block_interval
             ) do
        _ = Logger.info("Started State, height: #{height_query_result}, deposit height: #{last_deposit_query_result}")

        result
      else
        {:error, reason} = error when reason in [:top_block_number_not_found, :last_deposit_not_found] ->
          _ = Logger.error("It seems that Child chain database is not initialized. Check README.md")
          error

        other ->
          other
      end

    {:ok, _} = Recorder.start_link(%Recorder{name: __MODULE__.Recorder, parent: self()})

    {:noreply, state}
  end

  @doc """
  Checks (stateful validity) and executes a spend transaction. Assuming stateless validity!
  """
  def handle_call({:exec, tx, fees}, _from, state) do
    case Core.exec(state, tx, fees) do
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

    :ok = OMG.InternalEventBus.broadcast("events", {:emit_events, event_triggers})

    {:reply, {:ok, db_updates}, new_state}
  end

  @doc """
  Exits (spends) utxos on child chain, explicitly signals all utxos that have already been spent
  """
  def handle_call({:exit_utxos, utxos}, _from, state) do
    {:ok, {db_updates, validities}, new_state} = Core.exit_utxos(utxos, state)

    {:reply, {:ok, db_updates, validities}, new_state}
  end

  @doc """
  Tells if utxo exists
  """
  def handle_call({:utxo_exists, utxo}, _from, state) do
    {:reply, Core.utxo_exists?(utxo, state), state}
  end

  @doc """
      Gets the current block's height and whether at the beginning of a block.

      Beginning of block is true if and only if the last block has been committed
      and none transaction from the next block has been executed.
  """
  def handle_call(:get_status, _from, state) do
    {:reply, Core.get_status(state), state}
  end

  @doc """
  Works exactly like handle_cast(:form_block) but:
   - is synchronous
   - `eth_height` given is the Ethereum chain height where the block being closed got submitted, to be used with events.
   - relies on the caller to handle persistence, instead of handling itself

  Someday, one might want to skip some of computations done (like calculating the root hash, which is scrapped)
  """
  def handle_call({:close_block, eth_height}, _from, state) do
    {:ok, {block, event_triggers, db_updates}, new_state} = do_form_block(state, eth_height)

    publish_block_to_event_bus(block, event_triggers)
    {:reply, {:ok, db_updates}, new_state}
  end

  @doc """
  Wraps up accumulated transactions submissions into a block, triggers db update and:
   - pushes events to subscribers of `"event_triggers"` internal event bus topic
   - pushes the new block to subscribers of `"blocks"` internal event bus topic

  Does its on persistence!
  """
  @decorate measure_event()
  def handle_cast(:form_block, state) do
    _ = Logger.debug("Forming new block...")
    {:ok, {%Block{number: blknum} = block, event_triggers, db_updates}, new_state} = do_form_block(state)
    _ = Logger.debug("Formed new block ##{blknum}")

    # persistence is required to be here, since propagating the block onwards requires restartability including the
    # new block
    :ok = DB.multi_update(db_updates)

    publish_block_to_event_bus(block, event_triggers)
    {:noreply, new_state}
  end

  @decorate measure_event()
  defp do_form_block(state, eth_height \\ nil) do
    {:ok, child_block_interval} = Eth.RootChain.get_child_block_interval()
    Core.form_block(child_block_interval, eth_height, state)
  end

  defp publish_block_to_event_bus(block, event_triggers) do
    :ok = OMG.InternalEventBus.broadcast("events", {:emit_events, event_triggers})
    :ok = OMG.InternalEventBus.direct_local_broadcast("blocks", {:enqueue_block, block})
  end
end

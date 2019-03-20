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

defmodule OMG.State do
  @moduledoc """
  Imperative shell for the state.
  The state meant here is the state of the ledger (UTXO set), that determines spendability of coins and forms blocks.
  All spend transactions, deposits and exits should sync on this for validity of moving funds.
  """

  alias OMG.Block
  alias OMG.BlockQueueAPI
  alias OMG.DB
  alias OMG.Eth
  alias OMG.EventerAPI
  alias OMG.Fees
  alias OMG.Recorder
  alias OMG.State.Core
  alias OMG.State.Transaction
  alias OMG.Utxo

  use OMG.LoggerExt

  @type exec_error :: Core.exec_error()

  ### Client

  def start_link(_args) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @spec exec(tx :: %Transaction.Recovered{}, fees :: Fees.fee_t()) ::
          {:ok, {Transaction.tx_hash(), pos_integer, non_neg_integer}}
          | {:error, exec_error()}
  def exec(tx, input_fees) do
    GenServer.call(__MODULE__, {:exec, tx, input_fees})
  end

  def form_block do
    GenServer.cast(__MODULE__, :form_block)
  end

  @spec close_block(pos_integer) :: {:ok, list(Core.db_update())}
  def close_block(eth_height) do
    GenServer.call(__MODULE__, {:close_block, eth_height})
  end

  @spec deposit(deposits :: [Core.deposit()]) :: {:ok, list(Core.db_update())}
  def deposit(deposits) do
    GenServer.call(__MODULE__, {:deposits, deposits})
  end

  @spec exit_utxos(utxos :: Core.exiting_utxos_t()) ::
          {:ok, list(Core.exit_event()), list(Core.db_update()), Core.validities_t()}
  def exit_utxos(utxos) do
    GenServer.call(__MODULE__, {:exit_utxos, utxos})
  end

  @spec utxo_exists?(Utxo.Position.t()) :: boolean()
  def utxo_exists?(utxo) do
    GenServer.call(__MODULE__, {:utxo_exists, utxo})
  end

  @spec get_status :: {non_neg_integer(), boolean()}
  def get_status do
    GenServer.call(__MODULE__, :get_status)
  end

  ### Server

  use GenServer

  @doc """
  Start processing state using the database entries
  """
  def init(:ok) do
    {:ok, %{}, {:continue, :setup}}
  end

  def handle_continue(:setup, %{}) do
    {:ok, height_query_result} = DB.get_single_value(:child_top_block_number)
    {:ok, last_deposit_query_result} = DB.get_single_value(:last_deposit_child_blknum)
    {:ok, utxos_query_result} = DB.utxos()
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

    EventerAPI.emit_events(event_triggers)

    {:reply, {:ok, db_updates}, new_state}
  end

  @doc """
  Exits (spends) utxos on child chain, explicitly signals all utxos that have already been spent
  """
  def handle_call({:exit_utxos, utxos}, _from, state) do
    {:ok, {event_triggers, db_updates, validities}, new_state} = Core.exit_utxos(utxos, state)

    EventerAPI.emit_events(event_triggers)

    {:reply, {:ok, event_triggers, db_updates, validities}, new_state}
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
  Works exactly like handle_cast(:form_block) but is synchronous

  Also, eth_height given is the Ethereum chain height where the block being closed got submitted, to be used with events.

  Someday, one might want to skip some of computations done (like calculating the root hash, which is scrapped)

  Returns `db_updates` due and relies on the caller to do persistence
  """
  def handle_call({:close_block, eth_height}, _from, state) do
    {:ok, {_block, event_triggers, db_updates}, new_state} = do_form_block(state)

    event_triggers
    # enrich the event triggers with the ethereum height supplied
    |> Enum.map(&Map.put(&1, :submited_at_ethheight, eth_height))
    |> EventerAPI.emit_events()

    {:reply, {:ok, db_updates}, new_state}
  end

  @doc """
  Wraps up accumulated transactions submissions into a block, triggers db update and:
   - emits events to Eventer (if it is running, i.e. in Watcher).
   - pushes the new block into the respective service (if it is running, i.e. in Child Chain server)
   - enqueues the new block for submission to BlockQueue (if it is running, i.e. in Child Chain server)

  Does its on persistence!
  """
  def handle_cast(:form_block, state) do
    _ = Logger.debug("Forming new block...")

    {duration, {:ok, {%Block{number: blknum} = block, _events, db_updates}, new_state}} =
      :timer.tc(fn -> do_form_block(state) end)

    _ =
      Logger.info(
        "Calculations for forming block number #{inspect(blknum)} done in #{inspect(round(duration / 1000))} ms"
      )

    # persistence is required to be here, since propagating the block onwards requires restartability including the
    # new block
    :ok = DB.multi_update(db_updates)

    ### casts, note these are no-ops if given processes are turned off
    BlockQueueAPI.enqueue_block(block)

    {:noreply, new_state}
  end

  defp do_form_block(state) do
    {:ok, child_block_interval} = Eth.RootChain.get_child_block_interval()
    Core.form_block(child_block_interval, state)
  end
end

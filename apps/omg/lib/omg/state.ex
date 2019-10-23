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
  alias OMG.InputPointer
  alias OMG.State.Core
  alias OMG.State.Transaction
  alias OMG.State.Transaction.Validator
  alias OMG.Utxo

  use GenServer

  use OMG.Utils.LoggerExt

  @type exec_error :: Validator.exec_error()

  ### Client

  def start_link(_args) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @spec exec(tx :: Transaction.Recovered.t(), fees :: Fees.fee_t()) ::
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
  # empty list clause to not block state for a no-op
  def deposit([]), do: {:ok, []}

  def deposit(deposits) do
    GenServer.call(__MODULE__, {:deposits, deposits})
  end

  @spec exit_utxos(utxos :: Core.exiting_utxos_t()) ::
          {:ok, list(Core.db_update()), Core.validities_t()}
  # empty list clause to not block state for a no-op
  def exit_utxos([]), do: {:ok, [], {[], []}}

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

  @doc """
  Start processing state using the database entries
  """
  def init(:ok) do
    # Get data essential for the State and Blockgetter. And it takes a while. TODO - measure it!
    # Our approach is simply blocking the supervision boot tree
    # until we've processed history.
    # TODO(pnowosie): Above comment?
    {:ok, height_query_result} = DB.get_single_value(:child_top_block_number)
    {:ok, [height_query_result], {:continue, :setup}}
  end

  def handle_continue(:setup, [height_query_result]) do
    {:ok, child_block_interval} = Eth.RootChain.get_child_block_interval()

    {:ok, state} =
      with {:ok, _data} = result <- Core.extract_initial_state(height_query_result, child_block_interval) do
        _ = Logger.info("Started #{inspect(__MODULE__)}, height: #{height_query_result}}")

        {:ok, _} =
          :timer.send_interval(Application.fetch_env!(:omg, :metrics_collection_interval), self(), :send_metrics)

        result
      else
        {:error, reason} = error when reason in [:top_block_number_not_found] ->
          _ = Logger.error("It seems that Child chain database is not initialized. Check README.md")
          error

        other ->
          other
      end

    {:noreply, state}
  end

  def handle_info(:send_metrics, state) do
    :ok = :telemetry.execute([:process, __MODULE__], %{}, state)
    {:noreply, state}
  end

  @doc """
  Checks (stateful validity) and executes a spend transaction. Assuming stateless validity!
  """
  def handle_call({:exec, tx, fees}, _from, state) do
    utxos_query_result =
      tx |> Transaction.get_inputs() |> Enum.reject(&Core.utxo_exists?(&1, state)) |> Enum.map(&utxo_from_db/1)

    state
    # FIXME: put the above logic into a `Core.get_exec_db_queries` w/ unit tests
    # FIXME: testy, testy
    # FIXME: what if utxo is not found? it must be handled properly and tested
    |> Core.with_utxos(utxos_query_result)
    |> Core.exec(tx, fees)
    # FIXME must write pending txs to disk every time an exec goes through. Form block must flush those
    #       think how to read them back for full block accountability on fail-overs and upgrades
    #       IDEA: write pending tx on every `exec` and keep it in state too. On every `form_block`,
    #             check in-memory pending state:
    #             If it's empty, then read from DB (it's a failover, so I've not been in the master)
    #             If it isn't empty, just use it, (normal operation, I've been in the master)
    # FIXME cleany, cleany
    |> case do
      {:ok, tx_result, %Core{utxo_db_updates: db_updates} = new_state} ->
        :ok = DB.multi_update(db_updates)
        # FIXME move elsewhere?
        {:reply, {:ok, tx_result}, %Core{new_state | utxo_db_updates: []}}

      {tx_result, new_state} ->
        {:reply, tx_result, new_state}
    end
  end

  # FIXME: move
  defp utxo_from_db(input_pointer) do
    {:ok, utxo_kv} = DB.utxo(InputPointer.Protocol.to_db_key(input_pointer))
    utxo_kv
  end

  @doc """
  Includes a deposit done on the root chain contract (see above - not sure about this)
  """
  def handle_call({:deposits, deposits}, _from, state) do
    {:ok, {event_triggers, db_updates}, new_state} = Core.deposit(deposits, state)

    :ok = OMG.Bus.broadcast("events", {:preprocess_emit_events, event_triggers})

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

  defp do_form_block(state, eth_height \\ nil) do
    {:ok, child_block_interval} = Eth.RootChain.get_child_block_interval()
    Core.form_block(child_block_interval, eth_height, state)
  end

  defp publish_block_to_event_bus(block, event_triggers) do
    :ok = OMG.Bus.broadcast("events", {:preprocess_emit_events, event_triggers})
    :ok = OMG.Bus.direct_local_broadcast("blocks", {:enqueue_block, block})
  end
end

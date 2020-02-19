# Copyright 2019-2020 OmiseGO Pte Ltd
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

  alias OMG.State.Core
  alias OMG.State.Transaction
  alias OMG.State.Transaction.Validator
  alias OMG.State.UtxoSet
  alias OMG.Utxo

  use GenServer
  use OMG.Utils.LoggerExt

  require Utxo

  @type exec_error :: Validator.can_process_tx_error()

  ### Client

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @spec exec(tx :: Transaction.Recovered.t(), fees :: Fees.optional_fee_t()) ::
          {:ok, {Transaction.tx_hash(), pos_integer, non_neg_integer}}
          | {:error, exec_error()}
  def exec(tx, input_fees) do
    GenServer.call(__MODULE__, {:exec, tx, input_fees})
  end

  @spec form_block() :: :ok
  def form_block() do
    GenServer.cast(__MODULE__, :form_block)
  end

  # watcher
  @spec close_block() :: {:ok, list(Core.db_update())}
  def close_block() do
    GenServer.call(__MODULE__, :close_block)
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

  @spec get_status() :: {non_neg_integer(), boolean()}
  def get_status() do
    GenServer.call(__MODULE__, :get_status)
  end

  ### Server

  @doc """
  Initializes the state. UTXO set is not loaded now.
  """
  def init(opts) do
    {:ok, height_query_result} = DB.get_single_value(:child_top_block_number)
    {:ok, child_block_interval} = Eth.RootChain.get_child_block_interval()

    fee_claimer_address = Keyword.fetch!(opts, :fee_claimer_address)

    {:ok, state} =
      with {:ok, _data} = result <-
             Core.extract_initial_state(height_query_result, child_block_interval, fee_claimer_address) do
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

    {:ok, state}
  end

  def handle_info(:send_metrics, state) do
    :ok = :telemetry.execute([:process, __MODULE__], %{}, state)
    {:noreply, state}
  end

  @doc """
  Checks (stateful validity) and executes a spend transaction. Assuming stateless validity!
  """
  def handle_call({:exec, tx, fees}, _from, state) do
    db_utxos =
      tx
      |> Transaction.get_inputs()
      |> fetch_utxos_from_db(state)

    state
    |> Core.with_utxos(db_utxos)
    |> Core.exec(tx, fees)
    |> case do
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
    {:ok, db_updates, new_state} = Core.deposit(deposits, state)

    {:reply, {:ok, db_updates}, new_state}
  end

  @doc """
  Exits (spends) utxos on child chain, explicitly signals all utxos that have already been spent
  """
  def handle_call({:exit_utxos, utxos}, _from, state) do
    exiting_utxos = Core.extract_exiting_utxo_positions(utxos, state)

    db_utxos = fetch_utxos_from_db(exiting_utxos, state)
    state = Core.with_utxos(state, db_utxos)

    {:ok, {db_updates, validities}, new_state} = Core.exit_utxos(exiting_utxos, state)

    {:reply, {:ok, db_updates, validities}, new_state}
  end

  @doc """
  Tells if utxo exists
  """
  def handle_call({:utxo_exists, utxo}, _from, state) do
    db_utxos = fetch_utxos_from_db([utxo], state)
    new_state = Core.with_utxos(state, db_utxos)

    {:reply, Core.utxo_exists?(utxo, new_state), new_state}
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
   - relies on the caller to handle persistence, instead of handling itself

  Someday, one might want to skip some of computations done (like calculating the root hash, which is scrapped)
  """
  def handle_call(:close_block, _from, state) do
    {:ok, {block, db_updates}, new_state} = do_form_block(state)

    publish_block_to_event_bus(block)
    {:reply, {:ok, db_updates}, new_state}
  end

  @doc """
  Generates fee-transactions based on the fees paid in the block, wraps up accumulated transactions submissions
  and fee transactions into a block, triggers db update and:
   - pushes the new block to subscribers of `"blocks"` internal event bus topic

  Does its on persistence!
  """
  def handle_cast(:form_block, state) do
    _ = Logger.debug("Forming new block...")

    {:ok, {%Block{number: blknum} = block, db_updates}, new_state} =
      state
      |> Core.claim_fees()
      |> do_form_block()

    _ = Logger.debug("Formed new block ##{blknum}")

    # persistence is required to be here, since propagating the block onwards requires restartability including the
    # new block
    :ok = DB.multi_update(db_updates)

    publish_block_to_event_bus(block)
    {:noreply, new_state}
  end

  defp do_form_block(state) do
    {:ok, child_block_interval} = Eth.RootChain.get_child_block_interval()
    Core.form_block(child_block_interval, state)
  end

  defp publish_block_to_event_bus(block) do
    :ok = OMG.Bus.direct_local_broadcast("blocks", {:enqueue_block, block})
  end

  @spec fetch_utxos_from_db(list(OMG.Utxo.Position.t()), Core.t()) :: UtxoSet.t()
  defp fetch_utxos_from_db(utxo_pos_list, state) do
    utxo_pos_list
    |> Stream.reject(&Core.utxo_processed?(&1, state))
    |> Enum.map(&utxo_from_db/1)
    |> UtxoSet.init()
  end

  defp utxo_from_db(input_pointer) do
    # `DB` query can return `:not_found` which is filtered out by following `is_input_pointer?`
    with {:ok, utxo_kv} <- DB.utxo(Utxo.Position.to_input_db_key(input_pointer)),
         do: utxo_kv
  end
end

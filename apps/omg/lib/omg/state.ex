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
  A GenServer serving the ledger, for functional core and more info see `OMG.State.Core`.

  Keeps the state of the ledger, mainly the spendable UTXO set that can be employed in both `OMG.ChildChain` and
  `OMG.Watcher`.

  Maintains the state of the UTXO set by:
    - recognizing deposits
    - executing child chain transactions
    - recognizing exits

  Assumes that all stateless transaction validation is done outside of `exec/2`, so it accepts `OMG.State.Transaction.Recovered`
  """

  alias OMG.Block
  alias OMG.DB

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

  @timeout 10_000

  ### Client

  @doc """
  Starts the `GenServer` maintaining the ledger
  """
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Executes a single, statelessly validated child chain transaction. May take information on the fees required, in case
  fees are charged.

  Checks statefull validity and executes a transaction on `OMG.State` when successful. Otherwise, returns an error and has no effect on
  `OMG.State` and the ledger
  """
  @spec exec(tx :: Transaction.Recovered.t(), fees :: Fees.optional_fee_t()) ::
          {:ok, {Transaction.tx_hash(), pos_integer, non_neg_integer}}
          | {:error, exec_error()}
  def exec(tx, input_fees) do
    GenServer.call(__MODULE__, {:exec, tx, input_fees}, @timeout)
  end

  @doc """
  Intended for the `OMG.Watcher`. "Closes" a block, acknowledging that all transactions have been executed, and the next
  `exec/2` will belong to the next block.

  Depends on the caller to do persistence.

  Synchronous
  """
  @spec close_block() :: {:ok, list(Core.db_update())}
  def close_block() do
    GenServer.call(__MODULE__, :close_block, @timeout)
  end

  @doc """
  Intended for the `OMG.ChildChain`. Forms a new block and persist it. Broadcasts the block to the internal event bus
  to be used in other processes.

  Asynchronous
  """
  @spec form_block() :: :ok
  def form_block() do
    GenServer.cast(__MODULE__, :form_block)
  end

  @doc """
  Recognizes a list of deposits based on Ethereum events.

  Depends on the caller to do persistence.
  """
  @spec deposit(deposits :: [Core.deposit()]) :: {:ok, list(Core.db_update())}
  # empty list clause to not block state for a no-op
  def deposit([]), do: {:ok, []}

  def deposit(deposits) do
    GenServer.call(__MODULE__, {:deposit, deposits}, @timeout)
  end

  @doc """
  Recognizes a list of exits based on various triggers. Returns exit validities which indicate which of the UTXO positions
  actually pointed to UTXOs in the UTXO set of the ledger.

  For a list of things that can be triggers see `OMG.State.Core.extract_exiting_utxo_positions/2`.

  Depends on the caller to do persistence.
  """
  @spec exit_utxos(exiting_utxo_triggers :: Core.exiting_utxo_triggers_t()) ::
          {:ok, list(Core.db_update()), Core.validities_t()}
  # empty list clause to not block state for a no-op
  def exit_utxos([]), do: {:ok, [], {[], []}}

  def exit_utxos(exiting_utxo_triggers) do
    GenServer.call(__MODULE__, {:exit_utxos, exiting_utxo_triggers}, @timeout)
  end

  @doc """
  Provides a peek into the UTXO set to check if particular output exist (have not been spent)
  """
  @spec utxo_exists?(Utxo.Position.t()) :: boolean()
  def utxo_exists?(utxo) do
    GenServer.call(__MODULE__, {:utxo_exists, utxo}, @timeout)
  end

  @doc """
  Returns the current `blknum` and whether at the beginning of a block.

  The beginning of the block is `true/false` depending on whether there have been no transactions executed yet for
  the current child chain block
  """
  @spec get_status() :: {non_neg_integer(), boolean()}
  def get_status() do
    GenServer.call(__MODULE__, :get_status, @timeout)
  end

  ### Server

  @doc """
  Initializes the state. UTXO set is not loaded now.
  """
  def init(opts) do
    {:ok, child_top_block_number} = DB.get_single_value(:child_top_block_number)
    child_block_interval = Keyword.fetch!(opts, :child_block_interval)
    fee_claimer_address = Keyword.fetch!(opts, :fee_claimer_address)
    metrics_collection_interval = Keyword.fetch!(opts, :metrics_collection_interval)

    {:ok, _data} =
      result = Core.extract_initial_state(child_top_block_number, child_block_interval, fee_claimer_address)

    _ = Logger.info("Started #{inspect(__MODULE__)}, height: #{child_top_block_number}}")

    {:ok, _} = :timer.send_interval(metrics_collection_interval, self(), :send_metrics)

    result
  end

  def handle_info(:send_metrics, state) do
    :ok = :telemetry.execute([:process, __MODULE__], %{}, state)
    {:noreply, state}
  end

  @doc """
  see `exec/2`
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
  see `deposit/1`
  """
  def handle_call({:deposit, deposits}, _from, state) do
    {:ok, db_updates, new_state} = Core.deposit(deposits, state)

    {:reply, {:ok, db_updates}, new_state}
  end

  @doc """
  see `exit_utxos/1`

  Flow:
    - translates the triggers to UTXO positions digestible by the UTXO set
    - exits the UTXOs from the ledger if they exists, reports invalidity wherever they don't
    - returns the `db_updates` to be applied by the caller
  """
  def handle_call({:exit_utxos, exiting_utxo_triggers}, _from, state) do
    exiting_utxos = Core.extract_exiting_utxo_positions(exiting_utxo_triggers, state)

    db_utxos = fetch_utxos_from_db(exiting_utxos, state)
    state = Core.with_utxos(state, db_utxos)

    {:ok, {db_updates, validities}, new_state} = Core.exit_utxos(exiting_utxos, state)

    {:reply, {:ok, db_updates, validities}, new_state}
  end

  @doc """
  see `utxo_exists/1`
  """
  def handle_call({:utxo_exists, utxo_pos}, _from, state) do
    db_utxos = fetch_utxos_from_db([utxo_pos], state)
    new_state = Core.with_utxos(state, db_utxos)

    {:reply, Core.utxo_exists?(utxo_pos, new_state), new_state}
  end

  @doc """
  see `get_status/0`
  """
  def handle_call(:get_status, _from, state) do
    {:reply, Core.get_status(state), state}
  end

  @doc """
  see `close_block/0`

  Works exactly like `handle_cast(:form_block)` but:
   - is synchronous
   - relies on the caller to handle persistence, instead of handling itself

  Someday, one might want to skip some of computations done (like calculating the root hash, which is scrapped)
  """
  def handle_call(:close_block, _from, state) do
    {:ok, {_block, db_updates}, new_state} = Core.form_block(state)
    {:reply, {:ok, db_updates}, new_state}
  end

  @doc """
  see `form_block/0`

  Flow:
    - generates fee-transactions based on the fees paid in the block
    - wraps up accumulated transactions submissions and fee transactions into a block
    - triggers db update
    - pushes the new block to subscribers of `"blocks"` internal event bus topic
  """
  def handle_cast(:form_block, state) do
    _ = Logger.debug("Forming new block...")
    state = Core.claim_fees(state)
    {:ok, {%Block{number: blknum}, db_updates}, new_state} = Core.form_block(state)
    _ = Logger.debug("Formed new block ##{blknum}")

    # persistence is required to be here, since propagating the block onwards requires restartability including the
    # new block
    :ok = DB.multi_update(db_updates)

    {:noreply, new_state}
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

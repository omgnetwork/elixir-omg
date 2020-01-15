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

defmodule OMG.State.Core do
  @moduledoc """
  The state meant here is the state of the ledger (UTXO set), that determines spendability of coins and forms blocks.
  All spend transactions, deposits and exits should sync on this for validity of moving funds.

  We experienced long startup times on large UTXO set, which in some case caused timeouts and lethal `OMG.State`
  restart loop. To mitigate this issue we introduced loading UTXO set on demand (see GH#1103) instead of full load
  on process startup.

  During OMG.State startup no UTXOs are fetched from DB, which is no longer blocking significantly.
  Then during each of 6 utxo-related operations (see below) UTXO set is extended with UTXOs from DB to ensure operation
  behavior hasn't been changed.

  Transaction processing is populating the in-memory UTXO set and once block is formed newly created UTXO are inserted
  to DB, but are also kept in process State. Service restart looses all UTXO created by transactions processed as well
  as mempool transactions therefore DB content stays block-by-block consistent.

  Operations that require full ledger information are:
  - utxo_exists?
  - exec
  - form_block (and `close_block`)
  - deposit
  - exit_utxos

  These operations assume that passed `OMG.State.Core` struct instance contains sufficient UTXO information to proceed.
  Therefore the UTXOs that in-memory state is unaware of are fetched from the `OMG.DB` and then merged into state.
  As not every operation updates `OMG.DB` immediately additional `recently_spent` collection was added to in-memory
  state to defend against double spends in transactions within the same block.

  After block is formed `OMG.DB` contains full information up to the current block so we could waste in-memory
  info about utxos and spends. If the process gets restarted before form_block all mempool transactions along with
  created and spent utxos are lost and the ledger state basically resets to the previous block.
  """

  defstruct [
    :height,
    :fee_claimer_address,
    utxos: %{},
    pending_txs: [],
    tx_index: 0,
    utxo_db_updates: [],
    recently_spent: MapSet.new(),
    fees_paid: %{},
    fee_claiming_started: false
  ]

  alias OMG.Block
  alias OMG.Crypto
  alias OMG.Fees

  alias OMG.State.Core
  alias OMG.State.Transaction
  alias OMG.State.Transaction.Validator
  alias OMG.State.UtxoSet
  alias OMG.Utxo

  use OMG.Utils.LoggerExt
  require Utxo

  @type fee_summary_t() :: %{Transaction.Payment.currency() => pos_integer()}

  @type t() :: %__MODULE__{
          height: non_neg_integer(),
          utxos: utxos,
          pending_txs: list(Transaction.Recovered.t()),
          tx_index: non_neg_integer(),
          # NOTE: that this list is being build reverse, in some cases it may matter. It is reversed just before
          #       it leaves this module in `form_block/3`
          utxo_db_updates: list(db_update()),
          # NOTE: because UTXO set is not loaded from DB entirely, we need to remember the UTXOs spent in already
          # processed transaction before they get removed from DB on form_block.
          recently_spent: MapSet.t(OMG.Utxo.Position.t()),
          # Summarizes fees paid by pending transactions that will be formed into current block. Fees will be claimed
          # by appending `FeeTokenClaim` txs after pending txs in current block.
          fees_paid: fee_summary_t(),
          # fees can be claimed at the end of the block, no other payments can be processed until next block
          fee_claiming_started: boolean(),
          fee_claimer_address: Crypto.address_t()
        }

  @type deposit() :: %{
          root_chain_txhash: Crypto.hash_t(),
          log_index: non_neg_integer(),
          blknum: non_neg_integer(),
          currency: Crypto.address_t(),
          owner: Crypto.address_t(),
          amount: pos_integer()
        }

  @type exit_t() :: %{utxo_pos: pos_integer()}

  @type exit_finalization_t() :: %{utxo_pos: pos_integer()}

  @type exiting_utxos_t() ::
          [Utxo.Position.t()]
          | [non_neg_integer()]
          | [exit_t()]
          | [exit_finalization_t()]
          | [piggyback()]
          | [in_flight_exit()]

  @type in_flight_exit() :: %{in_flight_tx: binary()}
  @type piggyback() :: %{tx_hash: Transaction.tx_hash(), output_index: non_neg_integer}

  @type validities_t() :: {list(Utxo.Position.t()), list(Utxo.Position.t() | piggyback())}

  @type utxos() :: %{Utxo.Position.t() => Utxo.t()}

  @type db_update ::
          {:put, :utxo, {Utxo.Position.db_t(), map()}}
          | {:delete, :utxo, Utxo.Position.db_t()}
          | {:put, :child_top_block_number, pos_integer()}
          | {:put, :block, Block.db_t()}

  @type exitable_utxos :: %{
          owner: Crypto.address_t(),
          currency: Crypto.address_t(),
          amount: non_neg_integer(),
          blknum: pos_integer(),
          txindex: non_neg_integer(),
          oindex: non_neg_integer()
        }

  @doc """
  Initializes the state from the values stored in `OMG.DB`
  """
  @spec extract_initial_state(
          height_query_result :: non_neg_integer() | :not_found,
          child_block_interval :: pos_integer(),
          fee_claimer_address :: Crypto.address_t()
        ) :: {:ok, t()} | {:error, :top_block_number_not_found}
  def extract_initial_state(height_query_result, child_block_interval, fee_claimer_address)
      when is_integer(height_query_result) and is_integer(child_block_interval) do
    state = %__MODULE__{
      height: height_query_result + child_block_interval,
      fee_claimer_address: fee_claimer_address
    }

    {:ok, state}
  end

  def extract_initial_state(:not_found, _child_block_interval, _fee_claimer_address) do
    {:error, :top_block_number_not_found}
  end

  @doc """
  Tell whether utxo position was created or spent by current state.
  """
  @spec utxo_processed?(OMG.Utxo.Position.t(), t()) :: boolean()
  def utxo_processed?(utxo_pos, %Core{utxos: utxos, recently_spent: recently_spent}) do
    Map.has_key?(utxos, utxo_pos) or MapSet.member?(recently_spent, utxo_pos)
  end

  @doc """
  Extends in-memory utxo set with needed utxos loaded from DB
  See also: State.init_utxos_from_db/2
  """
  @spec with_utxos(t(), utxos()) :: t()
  def with_utxos(%Core{utxos: utxos} = state, db_utxos) do
    %{state | utxos: UtxoSet.apply_effects(utxos, [], db_utxos)}
  end

  @doc """
  Includes the transaction into the state when valid, rejects otherwise.

  NOTE that tx is assumed to have distinct inputs, that should be checked in prior state-less validation

  See docs/transaction_validation.md for more information about stateful and stateless validation.
  """
  @spec exec(state :: t(), tx :: Transaction.Recovered.t(), fees :: Fees.optional_fee_t()) ::
          {:ok, {Transaction.tx_hash(), pos_integer, non_neg_integer}, t()}
          | {{:error, Validator.process_error()}, t()}
  def exec(%Core{} = state, %Transaction.Recovered{} = tx, fees) do
    tx_hash = Transaction.raw_txhash(tx)

    case Validator.can_process(state, tx, fees) do
      {:ok, :apply_spend, fees_paid} ->
        {:ok, {tx_hash, state.height, state.tx_index},
         state
         |> apply_spend(tx)
         |> add_pending_tx(tx)
         |> collect_fees(fees_paid)}

      {:ok, :claim_fees, claimed_token} ->
        {:ok, {tx_hash, state.height, state.tx_index},
         state
         |> apply_spend(tx)
         |> add_pending_tx(tx)
         |> claim_token(claimed_token |> Map.keys() |> hd())
         |> disallow_payments()}

      {{:error, _reason}, _state} = error ->
        error
    end
  end

  @doc """
    Filter user utxos from db response.
    It may take a while for a large response from db
  """
  @spec standard_exitable_utxos(UtxoSet.query_result_t(), Crypto.address_t()) ::
          list(exitable_utxos)
  def standard_exitable_utxos(utxos_query_result, address) do
    utxos_query_result
    |> UtxoSet.init()
    |> UtxoSet.filter_owned_by(address)
    |> UtxoSet.zip_with_positions()
    |> Enum.map(fn {{_, utxo}, position} -> utxo_to_exitable_utxo_map(utxo, position) end)
  end

  # attempts to build a standard response data about a single UTXO, based on an abstract `output` structure
  # so that the data can be useful to discover exitable UTXOs
  defp utxo_to_exitable_utxo_map(%Utxo{output: output}, Utxo.position(blknum, txindex, oindex)) do
    output
    |> Map.from_struct()
    |> Map.take([:owner, :currency, :amount])
    |> Map.put(:blknum, blknum)
    |> Map.put(:txindex, txindex)
    |> Map.put(:oindex, oindex)
  end

  @doc """
   - Generates block and calculates it's root hash for submission
   - generates requests to the persistence layer for a block
   - processes pending txs gathered, updates height etc
   - clears `recently_spent` collection
  """
  @spec form_block(pos_integer(), state :: t(), fees :: Fees.optional_fee_t()) ::
          {:ok, {Block.t(), [db_update]}, new_state :: t()}
  def form_block(child_block_interval, %Core{} = state, fees) do
    # important: `claim_fees` changes state significantly, overriding the parameter
    %Core{
      height: height,
      pending_txs: reversed_txs,
      utxo_db_updates: reversed_utxo_db_updates
    } = state = claim_fees(state, fees)

    txs = Enum.reverse(reversed_txs)

    block = Block.hashed_txs_at(txs, height)

    db_updates_block = {:put, :block, Block.to_db_value(block)}
    db_updates_top_block_number = {:put, :child_top_block_number, height}

    db_updates = [db_updates_top_block_number, db_updates_block | reversed_utxo_db_updates] |> Enum.reverse()

    new_state = %Core{
      state
      | tx_index: 0,
        height: height + child_block_interval,
        pending_txs: [],
        utxo_db_updates: [],
        recently_spent: MapSet.new(),
        fees_paid: %{},
        fee_claiming_started: false
    }

    {:ok, {block, db_updates}, new_state}
  end

  @doc """
  Processes a deposit event, introducing a UTXO into the ledger's state. From then on it is spendable on the child chain

  **NOTE** this expects that each deposit event is fed to here exactly once, so this must be ensured elsewhere.
           There's no double-checking of this constraint done here.
  """
  @spec deposit(deposits :: [deposit()], state :: t()) :: {:ok, [db_update], new_state :: t()}
  def deposit(deposits, %Core{utxos: utxos} = state) do
    new_utxos_map = Enum.into(deposits, %{}, &deposit_to_utxo/1)
    new_utxos = UtxoSet.apply_effects(utxos, [], new_utxos_map)
    db_updates = UtxoSet.db_updates([], new_utxos_map)

    _ = if deposits != [], do: Logger.info("Recognized deposits #{inspect(deposits)}")

    new_state = %Core{state | utxos: new_utxos}
    {:ok, db_updates, new_state}
  end

  @doc """
  Retrieves exitable utxo positions from variety of exit events. Accepts either
   - a list of utxo positions (decoded)
   - a list of utxo positions (encoded)
   - a list of full exit infos containing the utxo positions
   - a list of full exit events (from ethereum listeners) containing the utxo positions
   - a list of IFE started events
   - a list of IFE input/output piggybacked events

  NOTE: It is done like this to accommodate different clients of this function as they can either be
  bare `EthereumEventListener` or `ExitProcessor`. Hence different forms it can get the exiting utxos delivered
  """
  @spec extract_exiting_utxo_positions(exiting_utxos_t(), t()) :: list(Utxo.Position.t())
  def extract_exiting_utxo_positions(exit_infos, state)

  def extract_exiting_utxo_positions([], %Core{}), do: []

  # list of full exit infos (from events) containing the utxo positions
  def extract_exiting_utxo_positions([%{utxo_pos: _} | _] = exit_infos, state),
    do: exit_infos |> Enum.map(& &1.utxo_pos) |> extract_exiting_utxo_positions(state)

  # list of full exit events (from ethereum listeners)
  def extract_exiting_utxo_positions([%{call_data: %{utxo_pos: _}} | _] = exit_infos, state),
    do: exit_infos |> Enum.map(& &1.call_data) |> extract_exiting_utxo_positions(state)

  # list of utxo positions (encoded)
  def extract_exiting_utxo_positions([encoded_utxo_pos | _] = exit_infos, %Core{}) when is_integer(encoded_utxo_pos),
    do: Enum.map(exit_infos, &Utxo.Position.decode!/1)

  # list of IFE input/output piggybacked events
  def extract_exiting_utxo_positions([%{call_data: %{in_flight_tx: _}} | _] = in_flight_txs, %Core{}) do
    _ = Logger.info("Recognized exits from IFE starts #{inspect(in_flight_txs)}")

    Enum.flat_map(in_flight_txs, fn %{call_data: %{in_flight_tx: tx_bytes}} ->
      {:ok, tx} = Transaction.decode(tx_bytes)
      Transaction.get_inputs(tx)
    end)
  end

  # list of IFE input piggybacked events (they're ignored)
  def extract_exiting_utxo_positions([%{tx_hash: _, omg_data: %{piggyback_type: :input}} | _] = piggybacks, %Core{}) do
    _ = Logger.info("Ignoring input piggybacks #{inspect(piggybacks)}")
    []
  end

  # list of IFE output piggybacked events. This is used by the child chain only. `OMG.Watcher.ExitProcessor` figures out
  # the utxo positions to exit on its own
  def extract_exiting_utxo_positions(
        [%{tx_hash: _, omg_data: %{piggyback_type: :output}} | _] = piggybacks,
        %Core{} = state
      ) do
    _ = Logger.info("Recognized exits from piggybacks #{inspect(piggybacks)}")

    piggybacks
    |> Enum.map(&find_utxo_matching_piggyback(&1, state))
    |> Enum.filter(fn utxo -> utxo != nil end)
    |> Enum.map(fn {position, _} -> position end)
  end

  # list of utxo positions (decoded)
  def extract_exiting_utxo_positions([Utxo.position(_, _, _) | _] = exiting_utxos, %Core{}), do: exiting_utxos

  @doc """
  Spends exited utxos.
  Note: state passed here is already extended with DB.
  """
  @spec exit_utxos(exiting_utxos :: list(Utxo.Position.t()), state :: t()) ::
          {:ok, {[db_update], validities_t()}, new_state :: t()}
  def exit_utxos([], %Core{} = state), do: {:ok, {[], {[], []}}, state}

  def exit_utxos(
        [Utxo.position(_, _, _) | _] = exiting_utxos,
        %Core{utxos: utxos, recently_spent: recently_spent} = state
      ) do
    _ = Logger.info("Recognized exits #{inspect(exiting_utxos)}")

    {valid, _invalid} = validities = Enum.split_with(exiting_utxos, &utxo_exists?(&1, state))

    new_utxos = UtxoSet.apply_effects(utxos, valid, %{})
    new_spends = MapSet.union(recently_spent, MapSet.new(valid))
    db_updates = UtxoSet.db_updates(valid, %{})
    new_state = %{state | utxos: new_utxos, recently_spent: new_spends}

    {:ok, {db_updates, validities}, new_state}
  end

  @doc """
  Checks whether utxo exists in UTXO set.
  Note: state passed here is already extended with DB.
  """
  @spec utxo_exists?(Utxo.Position.t(), t()) :: boolean()
  def utxo_exists?(Utxo.position(_blknum, _txindex, _oindex) = utxo_pos, %Core{utxos: utxos}) do
    UtxoSet.exists?(utxos, utxo_pos)
  end

  @doc """
      Gets the current block's height and whether at the beginning of the block
  """
  @spec get_status(t()) :: {current_block_height :: non_neg_integer(), is_block_beginning :: boolean()}
  def get_status(%__MODULE__{height: height, tx_index: tx_index, pending_txs: pending}) do
    is_beginning = tx_index == 0 && Enum.empty?(pending)
    {height, is_beginning}
  end

  defp add_pending_tx(%Core{pending_txs: pending_txs, tx_index: tx_index} = state, %Transaction.Recovered{} = new_tx) do
    %Core{
      state
      | tx_index: tx_index + 1,
        pending_txs: [new_tx | pending_txs]
    }
  end

  defp apply_spend(
         %Core{
           height: blknum,
           tx_index: tx_index,
           utxos: utxos,
           recently_spent: recently_spent,
           utxo_db_updates: db_updates
         } = state,
         %Transaction.Recovered{signed_tx: %{raw_tx: tx}}
       ) do
    {spent_input_pointers, new_utxos_map} = get_effects(tx, blknum, tx_index)
    new_utxos = UtxoSet.apply_effects(utxos, spent_input_pointers, new_utxos_map)
    new_db_updates = UtxoSet.db_updates(spent_input_pointers, new_utxos_map)
    # NOTE: child chain mode don't need 'spend' data for now. Consider to add only in Watcher's modes - OMG-382
    spent_blknum_updates = Enum.map(spent_input_pointers, &{:put, :spend, {Utxo.Position.to_input_db_key(&1), blknum}})

    %Core{
      state
      | utxos: new_utxos,
        recently_spent: MapSet.union(recently_spent, MapSet.new(spent_input_pointers)),
        utxo_db_updates: new_db_updates ++ spent_blknum_updates ++ db_updates
    }
  end

  defp collect_fees(%Core{fees_paid: fees_paid} = state, tx_fees) do
    %Core{
      state
      | fees_paid:
          Map.merge(fees_paid, tx_fees, fn _token, collected, tx_paid ->
            collected + tx_paid
          end)
    }
  end

  defp disallow_payments(state), do: %Core{state | fee_claiming_started: true}

  defp claim_token(state, token), do: %Core{state | fees_paid: Map.delete(state.fees_paid, token)}

  @spec claim_fees(state :: t(), fees :: Fees.optional_fee_t()) :: t()
  defp claim_fees(%Core{} = state, :no_fees_required), do: state

  defp claim_fees(
         %Core{
           height: height,
           fees_paid: fees_paid,
           fee_claimer_address: owner
         } = state,
         fees
       ) do
    fees_available_to_claim = Map.take(fees_paid, Map.keys(fees))

    Transaction.FeeTokenClaim.claim_collected(height, owner, fees_available_to_claim)
    |> Enum.map(fn fee_tx ->
      Transaction.Signed.encode(%Transaction.Signed{raw_tx: fee_tx, sigs: []})
    end)
    |> Enum.reduce(state, fn rlp_tx, curr_state ->
      {:ok, tx} = Transaction.Recovered.recover_from(rlp_tx)
      {:ok, _, new_state} = exec(curr_state, tx, fees)
      new_state
    end)
  end

  # Effects of a payment transaction - spends all inputs and creates all outputs
  # Relies on the polymorphic `get_inputs` and `get_outputs` of `Transaction`
  defp get_effects(tx, blknum, tx_index) do
    {Transaction.get_inputs(tx), utxos_from(tx, blknum, tx_index)}
  end

  defp utxos_from(tx, blknum, tx_index) do
    hash = Transaction.raw_txhash(tx)

    tx
    |> Transaction.get_outputs()
    |> Enum.with_index()
    |> Enum.map(fn {output, oindex} ->
      {Utxo.position(blknum, tx_index, oindex), output}
    end)
    |> Enum.into(%{}, fn {input_pointer, output} ->
      {input_pointer, %Utxo{output: output, creating_txhash: hash}}
    end)
  end

  defp deposit_to_utxo(%{blknum: blknum, currency: cur, owner: owner, amount: amount}) do
    Transaction.Payment.new([], [{owner, cur, amount}])
    |> utxos_from(blknum, 0)
    |> Enum.map(& &1)
    |> hd()
  end

  # We're looking for a UTXO that a piggyback of an in-flight IFE is referencing.
  # This is useful when trying to do something with the outputs that are piggybacked (like exit them), without their
  # position.
  # Only relevant for output piggybacks
  defp find_utxo_matching_piggyback(
         %{omg_data: %{piggyback_type: :output}, tx_hash: tx_hash, output_index: oindex},
         %Core{utxos: utxos}
       ),
       do: UtxoSet.find_matching_utxo(utxos, tx_hash, oindex)
end

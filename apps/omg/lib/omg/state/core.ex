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

defmodule OMG.State.Core do
  @moduledoc """
  The state meant here is the state of the ledger (UTXO set), that determines spendability of coins and forms blocks.
  All spend transactions, deposits and exits should sync on this for validity of moving funds.
  """

  defstruct [:height, utxos: %{}, pending_txs: [], tx_index: 0, utxo_db_updates: []]

  alias OMG.Block
  alias OMG.Crypto
  alias OMG.Fees
  alias OMG.InputPointer
  alias OMG.Output
  alias OMG.State.Core
  alias OMG.State.Transaction
  alias OMG.State.Transaction.Validator
  alias OMG.State.UtxoSet
  alias OMG.Utxo

  use OMG.Utils.LoggerExt
  require Utxo

  @type t() :: %__MODULE__{
          height: non_neg_integer(),
          utxos: utxos,
          pending_txs: list(Transaction.Recovered.t()),
          tx_index: non_neg_integer(),
          # NOTE: that this list is being build reverse, in some cases it may matter. It is reversed just before
          #       it leaves this module in `form_block/3`
          utxo_db_updates: list(db_update())
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

  @type deposit_event :: %{deposit: %{amount: non_neg_integer, owner: Crypto.address_t()}}
  @type tx_event :: %{
          tx: Transaction.Recovered.t(),
          child_blknum: pos_integer,
          child_txindex: pos_integer,
          child_block_hash: Block.block_hash_t()
        }

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
  Recovers the ledger's state from data delivered by the `OMG.DB`
  """
  @spec extract_initial_state(
          height_query_result :: non_neg_integer() | :not_found,
          child_block_interval :: pos_integer()
        ) :: {:ok, t()} | {:error, :top_block_number_not_found}
  def extract_initial_state(height_query_result, child_block_interval)
      when is_integer(height_query_result) and is_integer(child_block_interval) do
    state = %__MODULE__{height: height_query_result + child_block_interval}

    {:ok, state}
  end

  def extract_initial_state(:not_found, _child_block_interval) do
    {:error, :top_block_number_not_found}
  end

  @spec with_utxos(t(), UtxoSet.query_result_t()) :: t()
  def with_utxos(%Core{utxos: utxos} = state, utxos_query_result),
    do: %{state | utxos: UtxoSet.merge_with_query_result(utxos, utxos_query_result)}

  @doc """
  Includes the transaction into the state when valid, rejects otherwise.

  NOTE that tx is assumed to have distinct inputs, that should be checked in prior state-less validation

  See docs/transaction_validation.md for more information about stateful and stateless validation.
  """
  @spec exec(state :: t(), tx :: Transaction.Recovered.t(), fees :: Fees.fee_t()) ::
          {:ok, {Transaction.tx_hash(), pos_integer, non_neg_integer}, t()}
          | {{:error, Validator.exec_error()}, t()}
  def exec(%Core{} = state, %Transaction.Recovered{} = tx, fees) do
    tx_hash = Transaction.raw_txhash(tx)

    case Validator.can_apply_spend(state, tx, fees) do
      true ->
        {:ok, {tx_hash, state.height, state.tx_index},
         state
         |> apply_spend(tx)
         |> add_pending_tx(tx)}

      {{:error, _reason}, _state} = error ->
        error
    end
  end

  @spec exec_db_queries(
          state :: t(),
          tx :: Transaction.Recovered.t(),
          fees :: Fees.fee_t(),
          UtxoSet.query_result_t()
        ) ::
          {:ok, {Transaction.tx_hash(), pos_integer, non_neg_integer}, t()}
          | {{:error, Validator.exec_error()}, t()}
  def exec_db_queries(%Core{} = state, tx, fees, utxos_query_result) do
    state
    |> with_utxos(utxos_query_result)
    |> exec(tx, fees)
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
   - generates triggers for events
   - generates requests to the persistence layer for a block
   - processes pending txs gathered, updates height etc
  """
  @spec form_block(pos_integer(), pos_integer() | nil, state :: t()) ::
          {:ok, {Block.t(), [tx_event], [db_update]}, new_state :: t()}
  def form_block(
        child_block_interval,
        eth_height \\ nil,
        %Core{pending_txs: reversed_txs, height: height, utxo_db_updates: reversed_utxo_db_updates} = state
      ) do
    txs = Enum.reverse(reversed_txs)

    block = Block.hashed_txs_at(txs, height)

    event_triggers =
      txs
      |> Enum.with_index()
      |> Enum.map(fn {tx, index} ->
        %{tx: tx, child_blknum: block.number, child_txindex: index, child_block_hash: block.hash}
      end)
      # enrich the event triggers with the ethereum height supplied
      |> Enum.map(&Map.put(&1, :submited_at_ethheight, eth_height))

    db_updates_block = {:put, :block, Block.to_db_value(block)}
    db_updates_top_block_number = {:put, :child_top_block_number, height}

    db_updates = [db_updates_top_block_number, db_updates_block | reversed_utxo_db_updates] |> Enum.reverse()

    new_state = %Core{
      state
      | tx_index: 0,
        height: height + child_block_interval,
        pending_txs: [],
        utxo_db_updates: []
    }

    {:ok, {block, event_triggers, db_updates}, new_state}
  end

  @doc """
  Processes a deposit event, introducing a UTXO into the ledger's state. From then on it is spendable on the child chain

  **NOTE** this expects that each deposit event is fed to here exactly once, so this must be ensured elsewhere.
           There's no double-checking of this constraint done here.
  """
  @spec deposit(deposits :: [deposit()], state :: t()) :: {:ok, {[deposit_event], [db_update]}, new_state :: t()}
  def deposit(deposits, %Core{utxos: utxos} = state) do
    new_utxos_map = deposits |> Enum.into(%{}, &deposit_to_utxo/1)
    new_utxos = UtxoSet.apply_effects(utxos, [], new_utxos_map)
    db_updates = UtxoSet.db_updates([], new_utxos_map)

    event_triggers =
      deposits
      |> Enum.map(fn %{owner: owner, amount: amount} -> %{deposit: %{amount: amount, owner: owner}} end)

    _ = if deposits != [], do: Logger.info("Recognized deposits #{inspect(deposits)}")

    new_state = %Core{state | utxos: new_utxos}
    {:ok, {event_triggers, db_updates}, new_state}
  end

  @doc """
  Spends exited utxos. Accepts either
   - a list of utxo positions (decoded)
   - a list of utxo positions (encoded)
   - a list of full exit infos containing the utxo positions
   - a list of full exit events (from ethereum listeners) containing the utxo positions
   - a list of IFE started events
   - a list of IFE input/output piggybacked events

  NOTE: It is done like this to accommodate different clients of this function as they can either be
  bare `EthereumEventListener` or `ExitProcessor`. Hence different forms it can get the exiting utxos delivered
  """
  @spec exit_utxos(exiting_utxos :: exiting_utxos_t(), state :: t()) ::
          {:ok, {[db_update], validities_t()}, new_state :: t()}
  # empty list of whatever to bypass typing
  def exit_utxos([], %Core{} = state), do: {:ok, {[], {[], []}}, state}

  # list of full exit infos (from events) containing the utxo positions
  def exit_utxos([%{utxo_pos: _} | _] = exit_infos, %Core{} = state) do
    exit_infos |> Enum.map(& &1.utxo_pos) |> exit_utxos(state)
  end

  # list of full exit events (from ethereum listeners)
  def exit_utxos([%{call_data: %{utxo_pos: _}} | _] = exit_infos, %Core{} = state) do
    exit_infos |> Enum.map(& &1.call_data) |> exit_utxos(state)
  end

  # list of utxo positions (encoded)
  def exit_utxos([encoded_utxo_pos | _] = exit_infos, %Core{} = state) when is_integer(encoded_utxo_pos) do
    exit_infos |> Enum.map(&Utxo.Position.decode!/1) |> exit_utxos(state)
  end

  # list of IFE input/output piggybacked events
  def exit_utxos([%{call_data: %{in_flight_tx: _}} | _] = in_flight_txs, %Core{} = state) do
    _ = Logger.info("Recognized exits from IFE starts #{inspect(in_flight_txs)}")

    in_flight_txs
    |> Enum.flat_map(fn %{call_data: %{in_flight_tx: tx_bytes}} ->
      {:ok, tx} = Transaction.decode(tx_bytes)
      Transaction.get_inputs(tx)
    end)
    |> exit_utxos(state)
  end

  # list of IFE input piggybacked events (they're ignored)
  def exit_utxos([%{tx_hash: _, omg_data: %{piggyback_type: :input}} | _] = piggybacks, state) do
    _ = Logger.info("Ignoring input piggybacks #{inspect(piggybacks)}")
    {:ok, {[], {[], []}}, state}
  end

  # list of IFE output piggybacked events. This is used by the child chain only. `OMG.Watcher.ExitProcessor` figures out
  # the utxo positions to exit on its own
  def exit_utxos([%{tx_hash: _, omg_data: %{piggyback_type: :output}} | _] = piggybacks, state) do
    _ = Logger.info("Recognized exits from piggybacks #{inspect(piggybacks)}")

    piggybacks
    |> Enum.map(&find_utxo_matching_piggyback(&1, state))
    |> Enum.filter(& &1)
    |> Enum.map(fn {position, _} -> position end)
    |> exit_utxos(state)
  end

  # list of utxo positions (decoded)
  def exit_utxos([Utxo.position(_, _, _) | _] = exiting_utxos, %Core{utxos: utxos} = state) do
    _ = Logger.info("Recognized exits #{inspect(exiting_utxos)}")

    {valid, _invalid} = validities = Enum.split_with(exiting_utxos, &utxo_exists?(&1, state))

    new_utxos = UtxoSet.apply_effects(utxos, valid, %{})
    db_updates = UtxoSet.db_updates(valid, %{})
    new_state = %{state | utxos: new_utxos}

    {:ok, {db_updates, validities}, new_state}
  end

  @doc """
  Checks if utxo exists
  """
  @spec utxo_exists?(Utxo.Position.t(), t()) :: boolean()
  def utxo_exists?(Utxo.position(_blknum, _txindex, _oindex) = utxo_pos, %Core{utxos: utxos}),
    do: UtxoSet.exists?(utxos, utxo_pos)

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
         %Core{height: blknum, tx_index: tx_index, utxos: utxos, utxo_db_updates: db_updates} = state,
         %Transaction.Recovered{signed_tx: %{raw_tx: tx}}
       ) do
    {spent_input_pointers, new_utxos_map} = get_effects(tx, blknum, tx_index)
    new_utxos = UtxoSet.apply_effects(utxos, spent_input_pointers, new_utxos_map)
    new_db_updates = UtxoSet.db_updates(spent_input_pointers, new_utxos_map)
    # NOTE: child chain mode don't need 'spend' data for now. Consider to add only in Watcher's modes - OMG-382
    spent_blknum_updates =
      spent_input_pointers |> Enum.map(&{:put, :spend, {InputPointer.Protocol.to_db_key(&1), blknum}})

    %Core{state | utxos: new_utxos, utxo_db_updates: new_db_updates ++ spent_blknum_updates ++ db_updates}
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
      {Output.Protocol.input_pointer(output, blknum, tx_index, oindex, tx, hash), output}
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

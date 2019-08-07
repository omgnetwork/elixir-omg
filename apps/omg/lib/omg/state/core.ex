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

  defstruct [:height, :last_deposit_child_blknum, :utxos, pending_txs: [], tx_index: 0, utxo_db_updates: []]

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

  @type t() :: %__MODULE__{
          height: non_neg_integer(),
          last_deposit_child_blknum: non_neg_integer(),
          utxos: utxos,
          pending_txs: list(Transaction.Recovered.t()),
          tx_index: non_neg_integer(),
          # NOTE: that this list is being build reverse, in some cases it may matter. It is reversed just before
          #       it leaves this module in `form_block/3`
          utxo_db_updates: list(db_update())
        }

  @type deposit() :: %{
          root_chain_txhash: Crypto.hash_t(),
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
          | {:put, :last_deposit_child_blknum, pos_integer()}
          | {:put, :block, Block.db_t()}

  @type exitable_utxos :: %{
          creating_txhash: Transaction.tx_hash(),
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
          utxos_query_result :: [list({OMG.DB.utxo_pos_db_t(), OMG.Utxo.t()})],
          height_query_result :: non_neg_integer() | :not_found,
          last_deposit_child_blknum_query_result :: non_neg_integer() | :not_found,
          child_block_interval :: pos_integer()
        ) :: {:ok, t()} | {:error, :last_deposit_not_found | :top_block_number_not_found}
  def extract_initial_state(
        utxos_query_result,
        height_query_result,
        last_deposit_child_blknum_query_result,
        child_block_interval
      )
      when is_list(utxos_query_result) and is_integer(height_query_result) and
             is_integer(last_deposit_child_blknum_query_result) and is_integer(child_block_interval) do
    # extract height, last deposit height and utxos from query result
    height = height_query_result + child_block_interval

    state = %__MODULE__{
      height: height,
      last_deposit_child_blknum: last_deposit_child_blknum_query_result,
      utxos: UtxoSet.init(utxos_query_result)
    }

    {:ok, state}
  end

  def extract_initial_state(
        _utxos_query_result,
        _height_query_result,
        :not_found,
        _child_block_interval
      ) do
    {:error, :last_deposit_not_found}
  end

  def extract_initial_state(
        _utxos_query_result,
        :not_found,
        _last_deposit_child_blknum_query_result,
        _child_block_interval
      ) do
    {:error, :top_block_number_not_found}
  end

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

  @doc """
    Filter user utxos from db response.
    It may take a while for a large response from db
  """
  @spec standard_exitable_utxos(list({OMG.DB.utxo_pos_db_t(), OMG.Utxo.t()}), Crypto.address_t()) ::
          list(exitable_utxos)
  def standard_exitable_utxos(utxos_query_result, address) do
    Stream.filter(utxos_query_result, fn {_, %{owner: owner}} -> owner == address end)
    |> Enum.map(fn {{blknum, txindex, oindex}, utxo} ->
      utxo |> Map.put(:blknum, blknum) |> Map.put(:txindex, txindex) |> Map.put(:oindex, oindex)
    end)
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

  @spec deposit(deposits :: [deposit()], state :: t()) :: {:ok, {[deposit_event], [db_update]}, new_state :: t()}
  def deposit(deposits, %Core{utxos: utxos, last_deposit_child_blknum: last_deposit_child_blknum} = state) do
    deposits = deposits |> Enum.filter(&(&1.blknum > last_deposit_child_blknum))

    new_utxos_map = deposits |> Enum.into(%{}, &deposit_to_utxo/1)
    new_utxos = UtxoSet.apply_effects(utxos, [], new_utxos_map)
    db_updates_new_utxos = UtxoSet.db_updates([], new_utxos_map)

    event_triggers =
      deposits
      |> Enum.map(fn %{owner: owner, amount: amount} -> %{deposit: %{amount: amount, owner: owner}} end)

    last_deposit_child_blknum = get_last_deposit_child_blknum(deposits, last_deposit_child_blknum)

    db_updates = db_updates_new_utxos ++ last_deposit_child_blknum_db_update(deposits, last_deposit_child_blknum)

    _ = if deposits != [], do: Logger.info("Recognized deposits #{inspect(deposits)}")

    new_state = %Core{
      state
      | utxos: new_utxos,
        last_deposit_child_blknum: last_deposit_child_blknum
    }

    {:ok, {event_triggers, db_updates}, new_state}
  end

  @doc """
  Spends exited utxos. Accepts both a list of utxo positions (decoded) or full exit info from an event.

  NOTE: It is done like this to accommodate different clients of this function as they can either be
  bare `EthereumEventListener` or `ExitProcessor`. Hence different forms it can get the exiting utxos delivered
  """
  @spec exit_utxos(exiting_utxos :: exiting_utxos_t(), state :: t()) ::
          {:ok, {[db_update], validities_t()}, new_state :: t()}
  def exit_utxos([%{utxo_pos: _} | _] = exit_infos, %Core{} = state) do
    exit_infos |> Enum.map(& &1.utxo_pos) |> exit_utxos(state)
  end

  def exit_utxos([%{call_data: %{utxo_pos: _}} | _] = exit_infos, %Core{} = state) do
    exit_infos |> Enum.map(& &1.call_data) |> exit_utxos(state)
  end

  def exit_utxos([encoded_utxo_pos | _] = exit_infos, %Core{} = state) when is_integer(encoded_utxo_pos) do
    exit_infos |> Enum.map(&Utxo.Position.decode!/1) |> exit_utxos(state)
  end

  def exit_utxos([%{call_data: %{in_flight_tx: _}} | _] = in_flight_txs, %Core{} = state) do
    in_flight_txs
    |> Enum.flat_map(fn %{call_data: %{in_flight_tx: tx_bytes}} ->
      {:ok, tx} = Transaction.decode(tx_bytes)
      Transaction.get_inputs(tx)
    end)
    |> exit_utxos(state)
  end

  def exit_utxos([%{tx_hash: _} | _] = piggybacks, state) do
    {piggybacks_of_unknown_utxos, piggybacks_of_known_utxos} =
      piggybacks
      |> Enum.map(&find_utxo_matching_piggyback(&1, state))
      |> Enum.split_with(fn {_, position} -> position == nil end)

    {:ok, {db_updates, {valid, invalid}}, state} =
      piggybacks_of_known_utxos
      |> Enum.map(fn {_, {position, _}} -> position end)
      |> exit_utxos(state)

    {unknown_piggybacks, _} = Enum.unzip(piggybacks_of_unknown_utxos)

    {:ok, {db_updates, {valid, invalid ++ unknown_piggybacks}}, state}
  end

  def exit_utxos(exiting_utxos, %Core{utxos: utxos} = state) do
    _ = if exiting_utxos != [], do: Logger.info("Recognized exits #{inspect(exiting_utxos)}")

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
    {spent_input_pointers, new_utxos_map} = Transaction.Protocol.get_effects(tx, blknum, tx_index)
    new_utxos = UtxoSet.apply_effects(utxos, spent_input_pointers, new_utxos_map)
    new_db_updates = UtxoSet.db_updates(spent_input_pointers, new_utxos_map)
    # NOTE: child chain mode don't need 'spend' data for now. Consider to add only in Watcher's modes - OMG-382
    spent_blknum_updates = spent_input_pointers |> Enum.map(&{:put, :spend, {Utxo.Position.to_db_key(&1), blknum}})
    %Core{state | utxos: new_utxos, utxo_db_updates: new_db_updates ++ spent_blknum_updates ++ db_updates}
  end

  defp deposit_to_utxo(%{blknum: blknum, currency: cur, owner: owner, amount: amount}) do
    {Utxo.position(blknum, 0, 0), %Utxo{amount: amount, currency: cur, owner: owner}}
  end

  defp get_last_deposit_child_blknum([] = _deposits, current_height), do: current_height

  defp get_last_deposit_child_blknum(deposits, _current_height),
    do:
      deposits
      |> Enum.max_by(& &1.blknum)
      |> Map.get(:blknum)

  defp last_deposit_child_blknum_db_update([] = deposits, _last_deposit_child_blknum), do: deposits

  defp last_deposit_child_blknum_db_update(_deposits, last_deposit_child_blknum),
    do: [{:put, :last_deposit_child_blknum, last_deposit_child_blknum}]

  defp find_utxo_matching_piggyback(%{tx_hash: tx_hash, output_index: oindex} = piggyback, %Core{utxos: utxos}) do
    # oindex in contract is 0-7 where 4-7 are outputs
    oindex = oindex - 4
    position = UtxoSet.scan_for_matching_utxo(utxos, tx_hash, oindex)
    {piggyback, position}
  end
end

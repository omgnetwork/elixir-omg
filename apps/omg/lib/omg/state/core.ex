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

defmodule OMG.State.Core do
  @moduledoc """
  Functional core for State.
  """

  @maximum_block_size 65_536

  defstruct [:height, :last_deposit_child_blknum, :utxos, pending_txs: [], tx_index: 0]

  alias OMG.{Block, Crypto, Fees, Utxo}
  alias OMG.State.{Core, Transaction}

  use OMG.LoggerExt
  require Utxo

  @type t() :: %__MODULE__{
          height: non_neg_integer(),
          last_deposit_child_blknum: non_neg_integer(),
          utxos: utxos,
          pending_txs: list(Transaction.Recovered.t()),
          tx_index: non_neg_integer()
        }

  @type deposit() :: %{
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
  @type piggyback() :: %{txhash: Transaction.tx_hash(), output_index: non_neg_integer}

  @type validities_t() :: {list(Utxo.Position.t()), list(Utxo.Position.t())}

  @type utxos() :: %{Utxo.Position.t() => Utxo.t()}

  @type exec_error ::
          :unauthorized_spent
          | :amounts_do_not_add_up
          | :invalid_current_block_number
          | :utxo_not_found

  @type deposit_event :: %{deposit: %{amount: non_neg_integer, owner: Crypto.address_t()}}
  @type exit_event :: %{
          exit: %{owner: Crypto.address_t(), blknum: pos_integer, txindex: non_neg_integer, oindex: non_neg_integer}
        }
  @type tx_event :: %{
          tx: Transaction.Recovered.t(),
          child_blknum: pos_integer,
          child_txindex: pos_integer,
          child_block_hash: Block.block_hash_t()
        }

  @type db_update ::
          {:put, :utxo, {{pos_integer, non_neg_integer, non_neg_integer}, map}}
          | {:delete, :utxo, {pos_integer, non_neg_integer, non_neg_integer}}
          | {:put, :child_top_block_number, pos_integer}
          | {:put, :last_deposit_child_blknum, pos_integer}
          | {:put, :block, Block.t()}

  @spec extract_initial_state(
          utxos_query_result :: [utxos],
          height_query_result :: non_neg_integer | :not_found,
          last_deposit_child_blknum_query_result :: non_neg_integer | :not_found,
          child_block_interval :: pos_integer
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

    utxos =
      utxos_query_result
      |> Enum.into(%{}, fn {db_position, db_utxo} ->
        {Utxo.Position.from_db_key(db_position), Utxo.from_db_value(db_utxo)}
      end)

    state = %__MODULE__{
      height: height,
      last_deposit_child_blknum: last_deposit_child_blknum_query_result,
      utxos: utxos
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
          | {{:error, exec_error}, t()}
  def exec(
        %Core{height: height, tx_index: tx_index} = state,
        %Transaction.Recovered{tx_hash: tx_hash} = tx,
        fees
      ) do
    outputs = Transaction.get_outputs(tx)

    with :ok <- validate_block_size(state),
         {:ok, input_amounts_by_currency} <- correct_inputs?(state, tx),
         output_amounts_by_currency = get_amounts_by_currency(outputs),
         :ok <- amounts_add_up?(input_amounts_by_currency, output_amounts_by_currency),
         :ok <- transaction_covers_fee?(input_amounts_by_currency, output_amounts_by_currency, fees) do
      {:ok, {tx_hash, height, tx_index},
       state
       |> apply_spend(tx)
       |> add_pending_tx(tx)}
    else
      {:error, _reason} = error -> {error, state}
    end
  end

  defp correct_inputs?(%Core{utxos: utxos} = state, tx) do
    inputs = Transaction.get_inputs(tx)

    with :ok <- inputs_not_from_future_block?(state, inputs),
         {:ok, input_utxos} <- get_input_utxos(utxos, inputs),
         input_utxos_owners <- Enum.map(input_utxos, fn %{owner: owner} -> owner end),
         :ok <- Transaction.Recovered.all_spenders_authorized(tx, input_utxos_owners) do
      {:ok, get_amounts_by_currency(input_utxos)}
    end
  end

  defp inputs_not_from_future_block?(%__MODULE__{height: blknum}, inputs) do
    no_utxo_from_future_block =
      inputs
      |> Enum.all?(fn Utxo.position(input_blknum, _, _) -> blknum >= input_blknum end)

    if no_utxo_from_future_block, do: :ok, else: {:error, :input_utxo_ahead_of_state}
  end

  defp get_input_utxos(utxos, inputs) do
    inputs
    |> Enum.reduce_while({:ok, []}, fn input, acc -> get_utxos(utxos, input, acc) end)
  end

  defp get_utxos(utxos, position, {:ok, acc}) do
    case Map.get(utxos, position) do
      nil -> {:halt, {:error, :utxo_not_found}}
      found -> {:cont, {:ok, acc ++ [found]}}
    end
  end

  defp get_amounts_by_currency(utxos) do
    utxos
    |> Enum.group_by(fn %{currency: currency} -> currency end, fn %{amount: amount} -> amount end)
    |> Enum.map(fn {currency, amounts} -> {currency, Enum.sum(amounts)} end)
    |> Map.new()
  end

  defp amounts_add_up?(input_amounts, output_amounts) do
    for {output_currency, output_amount} <- Map.to_list(output_amounts) do
      input_amount = Map.get(input_amounts, output_currency, 0)
      input_amount >= output_amount
    end
    |> Enum.all?()
    |> if(do: :ok, else: {:error, :amounts_do_not_add_up})
  end

  def transaction_covers_fee?(input_amounts, output_amounts, fees) do
    Fees.covered?(input_amounts, output_amounts, fees)
    |> if(do: :ok, else: {:error, :fees_not_covered})
  end

  defp add_pending_tx(%Core{pending_txs: pending_txs, tx_index: tx_index} = state, %Transaction.Recovered{} = new_tx) do
    %Core{
      state
      | tx_index: tx_index + 1,
        pending_txs: [new_tx | pending_txs]
    }
  end

  defp apply_spend(%Core{height: height, tx_index: tx_index, utxos: utxos} = state, tx) do
    new_utxos_map = tx |> non_zero_utxos_from(height, tx_index) |> Map.new()

    inputs = Transaction.get_inputs(tx)
    utxos = Map.drop(utxos, inputs)
    %Core{state | utxos: Map.merge(utxos, new_utxos_map)}
  end

  defp non_zero_utxos_from(tx, height, tx_index) do
    tx
    |> utxos_from(height, tx_index)
    |> Enum.filter(fn {_key, value} -> is_non_zero_amount?(value) end)
  end

  defp utxos_from(%Transaction.Recovered{tx_hash: hash} = tx, height, tx_index) do
    outputs = Transaction.get_outputs(tx)

    for {%{owner: owner, currency: currency, amount: amount}, oindex} <- Enum.with_index(outputs) do
      {Utxo.position(height, tx_index, oindex),
       %Utxo{owner: owner, currency: currency, amount: amount, creating_txhash: hash}}
    end
  end

  defp is_non_zero_amount?(%{amount: 0}), do: false
  defp is_non_zero_amount?(%{amount: _}), do: true

  @doc """
   - Generates block and calculates it's root hash for submission
   - generates triggers for events
   - generates requests to the persistence layer for a block
   - processes pending txs gathered, updates height etc
  """
  @spec form_block(pos_integer(), pos_integer() | nil, state :: t()) ::
          {:ok, {Block.t(), [tx_event], [db_update]}, new_state :: t()}
  def form_block(child_block_interval, eth_height \\ nil, %Core{pending_txs: reverse_txs, height: height} = state) do
    txs = Enum.reverse(reverse_txs)

    block = txs |> Block.hashed_txs_at(height)

    event_triggers =
      txs
      |> Enum.with_index()
      |> Enum.map(fn {tx, index} ->
        %{tx: tx, child_blknum: block.number, child_txindex: index, child_block_hash: block.hash}
      end)
      # enrich the event triggers with the ethereum height supplied
      |> Enum.map(&Map.put(&1, :submited_at_ethheight, eth_height))

    db_updates_new_utxos =
      txs
      |> Enum.with_index()
      |> Enum.flat_map(fn {tx, tx_idx} -> non_zero_utxos_from(tx, height, tx_idx) end)
      |> Enum.map(&utxo_to_db_put/1)

    db_updates_spent_utxos =
      txs
      |> Enum.flat_map(&Transaction.get_inputs/1)
      |> Enum.flat_map(fn utxo_pos ->
        # NOTE: child chain mode don't need 'spend' data for now. Consider to add only in Watcher's modes - OMG-382
        db_key = Utxo.Position.to_db_key(utxo_pos)
        [{:delete, :utxo, db_key}, {:put, :spend, {db_key, height}}]
      end)

    db_updates_block = [{:put, :block, Block.to_db_value(block)}]

    db_updates_top_block_number = [{:put, :child_top_block_number, height}]

    db_updates =
      [db_updates_new_utxos, db_updates_spent_utxos, db_updates_block, db_updates_top_block_number]
      |> Enum.concat()

    new_state = %Core{
      state
      | tx_index: 0,
        height: height + child_block_interval,
        pending_txs: []
    }

    {:ok, {block, event_triggers, db_updates}, new_state}
  end

  @spec deposit(deposits :: [deposit()], state :: t()) :: {:ok, {[deposit_event], [db_update]}, new_state :: t()}
  def deposit(deposits, %Core{utxos: utxos, last_deposit_child_blknum: last_deposit_child_blknum} = state) do
    deposits = deposits |> Enum.filter(&(&1.blknum > last_deposit_child_blknum))

    new_utxos =
      deposits
      |> Enum.map(&deposit_to_utxo/1)

    event_triggers =
      deposits
      |> Enum.map(fn %{owner: owner, amount: amount} -> %{deposit: %{amount: amount, owner: owner}} end)

    last_deposit_child_blknum = get_last_deposit_child_blknum(deposits, last_deposit_child_blknum)

    db_updates_new_utxos =
      new_utxos
      |> Enum.map(&utxo_to_db_put/1)

    db_updates = db_updates_new_utxos ++ last_deposit_child_blknum_db_update(deposits, last_deposit_child_blknum)

    _ = if deposits != [], do: Logger.info("Recognized deposits #{inspect(deposits)}")

    new_state = %Core{
      state
      | utxos: Map.merge(utxos, Map.new(new_utxos)),
        last_deposit_child_blknum: last_deposit_child_blknum
    }

    {:ok, {event_triggers, db_updates}, new_state}
  end

  defp utxo_to_db_put({utxo_pos, utxo}),
    do: {:put, :utxo, {Utxo.Position.to_db_key(utxo_pos), Utxo.to_db_value(utxo)}}

  defp deposit_to_utxo(%{blknum: blknum, currency: cur, owner: owner, amount: amount}) do
    {Utxo.position(blknum, 0, 0), %Utxo{amount: amount, currency: cur, owner: owner}}
  end

  defp get_last_deposit_child_blknum(deposits, current_height) do
    if Enum.empty?(deposits) do
      current_height
    else
      deposits
      |> Enum.max_by(& &1.blknum)
      |> Map.get(:blknum)
    end
  end

  defp last_deposit_child_blknum_db_update(deposits, last_deposit_child_blknum) do
    if Enum.empty?(deposits) do
      []
    else
      [{:put, :last_deposit_child_blknum, last_deposit_child_blknum}]
    end
  end

  defp validate_block_size(%__MODULE__{tx_index: number_of_transactions_in_block}) do
    case number_of_transactions_in_block == @maximum_block_size do
      true -> {:error, :too_many_transactions_in_block}
      false -> :ok
    end
  end

  @doc """
  Spends exited utxos. Accepts both a list of utxo positions (decoded) or full exit info from an event.

  NOTE: It is done like this to accommodate different clients of this function as they can either be
  bare `EthereumEventListener` or `ExitProcessor`. Hence different forms it can get the exiting utxos delivered
  """
  @spec exit_utxos(exiting_utxos :: exiting_utxos_t(), state :: t()) ::
          {:ok, {[exit_event], [db_update], validities_t()}, new_state :: t()}
  def exit_utxos([%{utxo_pos: _} | _] = exit_infos, %Core{} = state) do
    exit_infos |> Enum.map(& &1.utxo_pos) |> exit_utxos(state)
  end

  def exit_utxos([%{call_data: %{utxo_pos: _}} | _] = exit_infos, %Core{} = state) do
    exit_infos |> Enum.map(& &1.call_data) |> exit_utxos(state)
  end

  def exit_utxos([encoded_utxo_pos | _] = exit_infos, %Core{} = state) when is_integer(encoded_utxo_pos) do
    exit_infos |> Enum.map(&Utxo.Position.decode/1) |> exit_utxos(state)
  end

  def exit_utxos([%{call_data: %{in_flight_tx: _}} | _] = in_flight_txs, %Core{} = state) do
    in_flight_txs
    |> Enum.flat_map(fn %{call_data: %{in_flight_tx: tx_bytes}} ->
      {:ok, tx} = Transaction.decode(tx_bytes)
      Transaction.get_inputs(tx)
    end)
    |> exit_utxos(state)
  end

  def exit_utxos([%{tx_hash: _} | _] = piggybacks, %Core{utxos: utxos} = state) do
    piggybacks
    |> Enum.map(fn %{tx_hash: tx_hash, output_index: oindex} ->
      # oindex in contract is 0-7 where 4-7 are outputs
      oindex = oindex - 4

      utxos
      |> Map.to_list()
      |> Enum.find(&match?({Utxo.position(_, _, ^oindex), %Utxo{creating_txhash: ^tx_hash}}, &1))
    end)
    |> Enum.filter(&(&1 != nil))
    |> Enum.map(fn {position, _} -> position end)
    |> exit_utxos(state)
  end

  def exit_utxos(exiting_utxos, %Core{utxos: utxos} = state) do
    _ =
      if exiting_utxos != [] do
        Logger.info("Recognized exits #{inspect(exiting_utxos)}")
      end

    {valid, _invalid} = validities = Enum.split_with(exiting_utxos, &utxo_exists?(&1, state))

    {event_triggers, db_updates} =
      valid
      |> Enum.map(fn Utxo.position(blknum, txindex, oindex) = utxo_pos ->
        %Utxo{amount: amount, owner: owner, currency: currency} = utxos[utxo_pos]

        {%{exit: %{owner: owner, amount: amount, currency: currency, utxo_pos: utxo_pos}},
         {:delete, :utxo, {blknum, txindex, oindex}}}
      end)
      |> Enum.unzip()

    new_state = %{state | utxos: Map.drop(utxos, valid)}

    {:ok, {event_triggers, db_updates, validities}, new_state}
  end

  @doc """
  Checks if utxo exists
  """
  @spec utxo_exists?(Utxo.Position.t(), t()) :: boolean()
  def utxo_exists?(Utxo.position(_blknum, _txindex, _oindex) = utxo_pos, %Core{utxos: utxos}) do
    Map.has_key?(utxos, utxo_pos)
  end

  @doc """
      Gets the current block's height and whether at the beginning of the block
  """
  @spec get_status(t()) :: {current_block_height :: non_neg_integer(), is_block_beginning :: boolean()}
  def get_status(%__MODULE__{height: height, tx_index: tx_index, pending_txs: pending}) do
    is_beginning = tx_index == 0 && Enum.empty?(pending)
    {height, is_beginning}
  end
end

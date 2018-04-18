defmodule OmiseGO.API.State.Core do
  @moduledoc """
  Functional core for State.
  """

  @maximum_block_size 65_536

  # TODO: consider structuring and naming files/modules differently, to not have bazillions of `X.Core` modules?
  defstruct [:height, :last_deposit_height, :utxos, pending_txs: [], tx_index: 0]

  alias OmiseGO.API.State.Transaction
  alias OmiseGO.API.State.Core
  alias OmiseGO.API.Block

  def extract_initial_state(
        utxos_query_result,
        height_query_result,
        last_deposit_height_query_result,
        child_block_interval
      ) do
    # extract height, last deposit height and utxos from query result
    height = height_query_result + child_block_interval

    utxos =
      utxos_query_result
      |> Enum.into(%{})

    %__MODULE__{
      height: height,
      last_deposit_height: last_deposit_height_query_result,
      utxos: utxos
    }
  end

  #TODO: Add specs :raw_tx, :signed_tx_hash, spender1: @zero_address, spender2: @zero_address
  def exec(%Transaction.Recovered{raw_tx: raw_tx, signed_tx_hash: _signed_tx_hash,
                                  spender1: spender1, spender2: spender2} = recovered_tx,
                                  %Core{utxos: utxos} = state) do

    %Transaction{amount1: amount1, amount2: amount2, fee: fee} = raw_tx

    with :ok <- validate_block_size(state),
         {:ok, in_amount1} <- correct_input?(utxos, raw_tx, 0, spender1),
         {:ok, in_amount2} <- correct_input?(utxos, raw_tx, 1, spender2),
         :ok <- amounts_add_up?(in_amount1 + in_amount2, amount1 + amount2 + fee) do
      {:ok,
       state
       |> add_pending_tx(recovered_tx)
       |> apply_spend(raw_tx),
       state.tx_index
       }
    else
      {:error, _reason} = error -> {error, state}
    end
  end

  defp add_pending_tx(%Core{pending_txs: pending_txs, tx_index: tx_index} = state, new_tx) do
    %Core{state | pending_txs: [{tx_index, new_tx} | pending_txs]}
  end

  # if there's no spender, make sure we cannot spend
  defp correct_input?(_, _, _, nil), do: {:ok, 0}

  # FIXME dry and move spender figuring out elsewhere
  defp correct_input?(
         utxos,
         %Transaction{blknum1: blknum, txindex1: txindex, oindex1: oindex},
         0,
         spender1
       ) do
    with {:ok, utxo} <- get_utxo(utxos, {blknum, txindex, oindex}),
         %{owner: owner, amount: owner_has} <- utxo,
         :ok <- is_spender?(owner, spender1),
         do: {:ok, owner_has}
  end

  defp correct_input?(
         utxos,
         %Transaction{blknum2: blknum, txindex2: txindex, oindex2: oindex},
         1,
         spender2
       ) do
    with {:ok, utxo} <- get_utxo(utxos, {blknum, txindex, oindex}),
         %{owner: owner, amount: owner_has} <- utxo,
         :ok <- is_spender?(owner, spender2),
         do: {:ok, owner_has}
  end

  defp get_utxo(_utxos, {0, 0, 0}), do: {:error, :cant_spend_zero_utxo}

  defp get_utxo(utxos, {blknum, txindex, oindex}) do
    case Map.get(utxos, {blknum, txindex, oindex}) do
      nil -> {:error, :utxo_not_found}
      found -> {:ok, found}
    end
  end

  defp is_spender?(owner, spender) do
    if owner == spender, do: :ok, else: {:error, :incorrect_spender}
  end

  defp amounts_add_up?(has, spends) do
    if has == spends, do: :ok, else: {:error, :amounts_dont_add_up}
  end

  defp apply_spend(
         %Core{height: height, tx_index: tx_index, utxos: utxos} =
           state,
         %Transaction{
           blknum1: blknum1,
           txindex1: txindex1,
           oindex1: oindex1,
           blknum2: blknum2,
           txindex2: txindex2,
           oindex2: oindex2
         } = tx
       ) do

    new_utxos = get_non_zero_amount_utxos(tx, height, tx_index)
    %Core{
      state
      | tx_index: tx_index + 1,
        utxos:
          utxos
          |> Map.merge(new_utxos)
          |> Map.delete({blknum1, txindex1, oindex1})
          |> Map.delete({blknum2, txindex2, oindex2})
    }
  end

  defp get_non_zero_amount_utxos(%Transaction{} = tx, height, tx_index) do
    tx
    |> get_utxos_at(height, tx_index)
    |> Enum.filter(fn {_key, value} -> is_non_zero_amount?(value) end)
    |> Map.new
  end

  defp get_utxos_at(%Transaction{} = tx, height, tx_index) do
    %{
      {height, tx_index, 0} => %{owner: tx.newowner1, amount: tx.amount1},
      {height, tx_index, 1} => %{owner: tx.newowner2, amount: tx.amount2}
    }
  end

  defp is_non_zero_amount?(%{amount: 0}), do: false
  defp is_non_zero_amount?(%{amount: _}), do: true

  @doc """
   - Generates block and calculates it's root hash for submission
   - generates triggers for events
   - generates requests to the persistence layer for a block
   - processes pending txs gathered, updates height etc
  """
  def form_block(
    %Core{pending_txs: reverse_txs, height: height} = state,
    block_num_to_form,
    next_block_num_to_form
  ) do
    with :ok <- validate_block_number(block_num_to_form, state) do

      txs = Enum.reverse(reverse_txs)

      block =
        txs
        |> Enum.map(fn {_tx_index, tx} -> tx end)
        |> (fn txs -> %Block{transactions: txs} end).()
        |> Block.merkle_hash()

      event_triggers =
        txs
        |> Enum.map(fn {_tx_index, tx} -> %{tx: tx} end)

      # TODO: consider calculating this along with updating the `utxos` field in the state for consistency
      db_updates_new_utxos =
        txs
        |> Enum.flat_map(fn {tx_index, %{raw_tx: tx}} -> get_non_zero_amount_utxos(tx, height, tx_index) end)
        |> Enum.map(fn {new_utxo_key, new_utxo} -> {:put, :utxo, %{new_utxo_key => new_utxo}} end)

      db_updates_spent_utxos =
        txs
        |> Enum.flat_map(fn {_tx_index, %{raw_tx: tx}} ->
          [{tx.blknum1, tx.txindex1, tx.oindex1}, {tx.blknum2, tx.txindex2, tx.oindex2}]
        end)
        |> Enum.filter(fn utxo_key -> utxo_key != {0, 0, 0} end)
        |> Enum.map(fn utxo_key -> {:delete, :utxo, utxo_key} end)

      db_updates_block = [{:put, :block, block}]

      db_updates =
        [db_updates_new_utxos, db_updates_spent_utxos, db_updates_block]
        |> Enum.concat()

      new_state = %Core{
        state
        | tx_index: 0,
          height: next_block_num_to_form,
          pending_txs: []
      }

      {:ok, {block, event_triggers, db_updates, new_state}}
    end
  end

  defp validate_block_number(expected_block_num, %Core{height: height}) do
    if expected_block_num == height, do: :ok, else: {:error, :invalid_current_block_number}
  end

  def deposit(deposits, %Core{utxos: utxos, last_deposit_height: last_deposit_height} = state) do
    deposits = deposits |> Enum.filter(&(&1.blknum > last_deposit_height))

    new_utxos =
      deposits
      |> Map.new(
          fn %{blknum: blknum, owner: owner, amount: amount} ->
            {{blknum, 0, 0}, %{amount: amount, owner: owner}}
          end)

    event_triggers =
      deposits
      |> Enum.map(fn %{owner: owner, amount: amount} -> %{deposit: %{amount: amount, owner: owner}} end)

    last_deposit_height = get_last_deposit_height(deposits, last_deposit_height)

    # FIXME dry the function transforming utxos to db puts
    db_updates_new_utxos =
      new_utxos
      |> Enum.map(fn {new_utxo_key, new_utxo} -> {:put, :utxo, %{new_utxo_key => new_utxo}} end)

    db_updates = db_updates_new_utxos ++ last_deposit_height_db_update(deposits, last_deposit_height)

    new_state =
      %Core{state |
       utxos: Map.merge(utxos, new_utxos),
       last_deposit_height: last_deposit_height
     }

    {event_triggers, db_updates, new_state}
  end

  defp get_last_deposit_height(deposits, current_height) do
    if Enum.empty?(deposits) do
      current_height
    else
        deposits
        |> Enum.max_by(&(&1.blknum))
        |> Map.get(:blknum)
    end
  end

  defp last_deposit_height_db_update(deposits, last_deposit_height) do
    if Enum.empty?(deposits) do
      []
    else
      [{:put, :last_deposit_block_height, last_deposit_height}]
    end
  end

  defp validate_block_size(
      %__MODULE__{tx_index: number_of_transactions_in_block}
    ) do
    case number_of_transactions_in_block == @maximum_block_size do
      true -> {:error, :too_many_transactions_in_block}
      false -> :ok
    end
  end

  @doc """
  Spends exited utxos
  """
  def exit_utxos(exiting_utxos, %Core{utxos: utxos} = state) do
    exiting_utxos =
      exiting_utxos
      |> Enum.filter(fn %{blknum: blknum, txindex: txindex, oindex: oindex} ->
          Map.has_key?(utxos, {blknum, txindex, oindex}) end)

    event_triggers = exiting_utxos
      |> Enum.map(fn %{owner: owner, blknum: blknum, txindex: txindex, oindex: oindex} ->
        %{exit: %{owner: owner, blknum: blknum, txindex: txindex, oindex: oindex}} end)
    state =
      exiting_utxos
      |> Enum.reduce(state, fn (%{blknum: blknum, txindex: txindex, oindex: oindex}, state) ->
        %{state | utxos: Map.delete(state.utxos, {blknum, txindex, oindex})} end)
    deletes =
      exiting_utxos
      |> Enum.map(fn %{blknum: blknum, txindex: txindex, oindex: oindex} ->
        {:delete, :utxo, {blknum, txindex, oindex}} end)

    {event_triggers, deletes, state}
  end
end

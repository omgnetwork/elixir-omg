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

  def extract_initial_state(_utxos_query_result, _height_query_result, _last_deposit_height_query_result) do
    # extract height, last deposit height and utxos from query result
    # FIXME
    height = 1
    # FIXME
    utxos = %{}
    %__MODULE__{height: height, last_deposit_height: 0, utxos: utxos}
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
       |> apply_spend(raw_tx)
       |> add_pending_tx(recovered_tx)}
    else
      {:error, _reason} = error -> {error, state}
    end
  end

  defp add_pending_tx(%Core{pending_txs: pending_txs} = state, new_tx) do
    %Core{state | pending_txs: [new_tx] ++ pending_txs}
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

    new_utxos = get_non_zero_amount_utxos(height, tx_index, tx)
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

  defp get_non_zero_amount_utxos(_, _, %Transaction{amount1: 0, amount2: 0}), do: %{}
  defp get_non_zero_amount_utxos(height, tx_index, %Transaction{amount1: 0} = tx) do
    %{{height, tx_index, 1} => %{owner: tx.newowner2, amount: tx.amount2}}
  end
  defp get_non_zero_amount_utxos(height, tx_index, %Transaction{amount2: 0} = tx) do
    %{{height, tx_index, 0} => %{owner: tx.newowner1, amount: tx.amount1}}
  end
  defp get_non_zero_amount_utxos(height, tx_index, %Transaction{} = tx) do
    %{
      {height, tx_index, 0} => %{owner: tx.newowner1, amount: tx.amount1},
      {height, tx_index, 1} => %{owner: tx.newowner2, amount: tx.amount2}
    }
  end

  def form_block(%Core{pending_txs: txs} = state, block_num_to_form, next_block_num_to_form) do
    # block generation
    # generating event triggers
    # generate requests to persistence
    # drop pending txs from state, update height etc.
    with :ok <- validate_block_number(block_num_to_form, state) do
      block = %Block{transactions: Enum.reverse(txs)} |> Block.merkle_hash()

      event_triggers =
        txs
        |> Enum.map(fn tx -> %{tx: tx} end)

      db_updates = []

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
    deposits = deposits |> Enum.filter(&(&1.block_height > last_deposit_height))

    new_utxos =
      deposits
      |> Map.new(
          fn %{block_height: height, owner: owner, amount: amount} ->
            {{height, 0, 0}, %{amount: amount, owner: owner}}
          end)

    event_triggers =
      deposits
      |> Enum.map(fn %{owner: owner, amount: amount} -> %{deposit: %{amount: amount, owner: owner}} end)

    last_deposit_height = get_last_deposit_height(deposits, last_deposit_height)
    db_updates = deposit_db_updates(deposits, last_deposit_height)

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
        |> Enum.max_by(&(&1.block_height))
        |> Map.get(:block_height)
    end
  end

  defp deposit_db_updates(deposits, last_deposit_height) do
    if Enum.empty?(deposits) do
      []
    else
      [{:last_deposit_block_height, last_deposit_height}]
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
end

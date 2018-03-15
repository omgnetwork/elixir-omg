defmodule OmiseGO.API.State.Core do
  @moduledoc """
  Functional core for State.
  """

  # TODO: consider structuring and naming files/modules differently, to not have bazillions of `X.Core` modules?
  defstruct [:height, :utxos, pending_txs: [], tx_index: 0]

  alias OmiseGO.API.State.Transaction
  alias OmiseGO.API.State.Core

  def extract_initial_state(_utxos_query_result, _height_query_result) do
    # extract height and utxos from query result
    # FIXME
    height = 1
    # FIXME
    utxos = %{}
    %__MODULE__{height: height, utxos: utxos}
  end

  def exec(
        %Transaction.Recovered{
          raw_tx: %Transaction{fee: fee, amount1: amount1, amount2: amount2} = tx,
          spender1: spender1,
          spender2: spender2
        },
        %Core{utxos: utxos} = state
      ) do
    with {:ok, in_amount1} <- correct_input?(utxos, tx, 0, spender1),
         {:ok, in_amount2} <- correct_input?(utxos, tx, 1, spender2),
         :ok <- amounts_add_up?(in_amount1 + in_amount2, amount1 + amount2 + fee) do
      {:ok,
       state
       |> apply_spend(tx)
       |> add_pending_tx(tx)}
    else
      {:error, _reason} = error -> {error, state}
    end
  end

  defp add_pending_tx(%Core{pending_txs: pending_txs} = state, new_tx) do
    %Core{state | pending_txs: [new_tx] ++ pending_txs}
  end

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

  defp get_utxo(_utxos, {0, 0, 0}), do: {:ok, %{amount: 0, owner: Transaction.zero_address()}}

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
    new_utxos = %{
      # FIXME: don't insert 0 amount utxos
      {height, tx_index, 0} => %{owner: tx.newowner1, amount: tx.amount1},
      {height, tx_index, 1} => %{owner: tx.newowner2, amount: tx.amount2}
    }

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

  def form_block(%Core{height: height, pending_txs: txs} = state) do
    # block generation
    # generating event triggers
    # generate requests to persistence
    # drop pending txs from state, update height etc.
    block = %{}

    event_triggers =
      txs
      |> Enum.map(fn tx -> %{tx: tx} end)

    db_updates = []

    new_state = %Core{
      state
      | tx_index: 0,
        height: height + 1,
        pending_txs: []
    }

    {block, event_triggers, db_updates, new_state}
  end

  def deposit(owner, amount, %Core{height: height, utxos: utxos} = state) do
    new_utxos = %{{height, 0, 0} => %{amount: amount, owner: owner}}

    event_triggers = [%{deposit: %{amount: amount, owner: owner}}]

    db_updates = []

    new_state = %Core{
      state
      | height: height + 1,
        utxos: Map.merge(utxos, new_utxos)
    }

    {event_triggers, db_updates, new_state}
  end
end

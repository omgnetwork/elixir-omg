defmodule OMG.Transaction do
  use GenServer
  @maximum_block_size 65_536
  defstruct [
    :height,
    :utxos,
    :tx_index,
    :fees,
    :tx,
    :hash,
    :data_holder,
    :inputs,
    maximum_block_size: @maximum_block_size
  ]

  @type t() :: %__MODULE__{
          height: non_neg_integer(),
          utxos: %{Utxo.Position.t() => Utxo.t()},
          tx_index: non_neg_integer(),
          fees: OMG.Fees.fee_t(),
          tx: OMG.Transaction.Recovered.t(),
          hash: Transaction.tx_hash(),
          data_holder: module(),
          inputs: list(OMG.Transaction.Payment.input()),
          maximum_block_size: non_neg_integer()
        }

  # @spec process_transaction(tx :: OMG.Transaction.Recovered.t()) ::
  #         {:ok, {Transaction.tx_hash(), pos_integer, non_neg_integer}}
  #         | {:error, exec_error()}
  def process_transaction(tx) do
    GenServer.call(__MODULE__, {:process_transaction, %__MODULE__{tx: tx}})
  end

  def init(init_arg), do: {:ok, init_arg}

  @doc """
  Checks (stateful validity) and executes a spend transaction. Assuming stateless validity!
  """
  def handle_call({:process_transaction, transaction}, _from, _state) do
    steps = [
      # add recover transaction steps here
      &Processor.get_transaction_fees/1,
      &Processor.get_transaction_data/1,
      &Processor.get_inputs/1,
      &Processor.validate_block_size/1,
      &Processor.check_if_inputs_not_from_future_block/1,
      &Processor.check_if_fees_covered/1,
      &Processor.apply_spend/1,
      &Processor.add_pending_tx/1
    ]

    Enum.reduce_while(steps, transaction, fn step ->
      case apply(step, [transaction]) do
        result when is_map(result) -> {:cont, result}
        error_result -> {:halt, error_result}
      end
    end)
  end

  # case exec(state, tx, fees) do
  #   {:ok, tx_result, new_state} ->
  #     {:reply, {:ok, tx_result}, new_state}

  #   {tx_result, new_state} ->
  #     {:reply, tx_result, new_state}
  # end

  # @doc """
  # Includes the transaction into the state when valid, rejects otherwise.

  # NOTE that tx is assumed to have distinct inputs, that should be checked in prior state-less validation

  # See docs/transaction_validation.md for more information about stateful and stateless validation.
  # """
  # @spec exec(state :: t(), tx :: OMG.Transaction.Recovered.t(), fees :: Fees.fee_t()) ::
  #         {:ok, {Transaction.tx_hash(), pos_integer, non_neg_integer}, t()}
  #         | {{:error, Validator.exec_error()}, t()}
  # def exec(%Core{} = state, %OMG.Transaction.Recovered{} = tx, fees) do
  #   tx_hash = OMG.Transaction.Extract.raw_txhash(tx)

  #   case Validator.can_apply_spend(state, tx, fees) do
  #     true ->
  #       {:ok, {tx_hash, state.height, state.tx_index},
  #        state
  #        |> apply_spend(tx)
  #        |> add_pending_tx(tx)}

  #     {{:error, _reason}, _state} = error ->
  #       error
  #   end
  # end
end

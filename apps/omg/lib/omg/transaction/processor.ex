defmodule OMG.Transaction.Processor do
  alias OMG.Transaction
  alias OMG.Fees
  require OMG.Utxo

  def get_transaction_fees(%Transaction{tx: tx} = transaction) do
    fees = Fees.for_tx(tx, FeeServer.transaction_fees())
    %{transaction | fees: fees}
  end

  def get_transaction_data(%Transaction{data_holder: data_holder} = transaction) do
    {:ok, utxos, tx_index, height} = apply(data_holder, :transaction_requirements, [])
    %{transaction | utxos: utxos, tx_index: tx_index, height: height}
  end

  def get_inputs(%Transaction{tx: tx} = transaction) do
    inputs = OMG.State.OMG.Transaction.Extract.get_inputs(tx)
    %{transaction | inputs: inputs}
  end

  def validate_block_size(
        %OMG.Transaction{tx_index: number_of_transactions_in_block, maximum_block_size: maximum_block_size} =
          transaction
      ) do
    case number_of_transactions_in_block do
      ^maximum_block_size -> {:error, :too_many_transactions_in_block}
      _ -> transaction
    end
  end

  def inputs_not_from_future_block?(%OMG.Transaction{height: height, inputs: inputs} = transaction) do
    no_utxo_from_future_block =
      Enum.all?(
        inputs,
        fn OMG.Utxo.position(input_blknum, _, _) ->
          height >= input_blknum
        end
      )

    if no_utxo_from_future_block, do: transaction, else: {:error, :input_utxo_ahead_of_state}
  end

  @spec check_if_fees_covered(__MODULE__.t()) ::
          __MODULE__.t() | {:error, :amounts_do_not_add_up | :unauthorized_spent | :utxo_not_found | :fees_not_covered}
  def check_if_fees_covered(%OMG.Transaction{utxos: utxos, inputs: inputs, tx: tx, fees: fees} = transaction) do
    with {:ok, input_utxos} <- UtxoSet.get_by_inputs(utxos, inputs),
         {:ok, implicit_paid_fee_by_currency} <- OMG.Transaction.Recovered.can_apply?(tx, input_utxos),
         true <- Fees.covered?(implicit_paid_fee_by_currency, fees) || {:error, :fees_not_covered} do
      transaction
    else
      {:error, _reason} = error -> error
    end
  end
end

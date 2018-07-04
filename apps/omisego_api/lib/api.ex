defmodule OmiseGO.API do
  @moduledoc """
  Entrypoint for all the exposed public functions of the child chain API.

  Should handle all the initial processing of requests like state-less validity, decoding/encoding
  (but not transport-specific encoding like hex).
  """

  alias OmiseGO.API.{Block, Core, FeeChecker, FreshBlocks, State}
  use OmiseGO.API.ExposeSpec

  @spec submit(transaction :: bitstring) ::
          {:ok, %{tx_hash: bitstring, blknum: integer, tx_index: integer}} | {:error, atom}
  def submit(transaction) do
    with {:ok, recovered_tx} <- Core.recover_tx(transaction),
         {:ok, input_fees} <- FeeChecker.transaction_fees(recovered_tx),
         {:ok, tx_hash, blknum, tx_index} <- State.exec(recovered_tx, input_fees) do
      {:ok, %{tx_hash: tx_hash, blknum: blknum, tx_index: tx_index}}
    end
  end

  @spec get_block(hash :: bitstring) ::
          {:ok, %{hash: bitstring, transactions: list}} | {:error, :not_found | :internal_error}
  def get_block(hash) do
    with {:ok, %Block{hash: ^hash, transactions: transactions}} <- FreshBlocks.get(hash) do
      {:ok, %{hash: hash, transactions: transactions |> Enum.map(& &1.signed_tx_bytes)}}
    end
  end
end

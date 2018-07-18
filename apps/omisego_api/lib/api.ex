defmodule OmiseGO.API do
  @moduledoc """
  Entrypoint for all the exposed public functions of the child chain API.

  Should handle all the initial processing of requests like state-less validity, decoding/encoding
  (but not transport-specific encoding like hex).
  """

  require Logger

  alias OmiseGO.API.{Block, Core, FeeChecker, FreshBlocks, State}
  use OmiseGO.API.ExposeSpec

  @spec submit(transaction :: bitstring) ::
          {:ok, %{tx_hash: bitstring, blknum: integer, tx_index: integer}} | {:error, atom}
  def submit(transaction) do
    result =
      with {:ok, recovered_tx} <- Core.recover_tx(transaction),
          {:ok, fees} <- FeeChecker.transaction_fees(recovered_tx),
          {:ok, tx_hash, blknum, tx_index} <- State.exec(recovered_tx, fees) do
        {:ok, %{tx_hash: tx_hash, blknum: blknum, tx_index: tx_index}}
      end

    result
    |> OmiseGO.API.LoggerHelpers.result_to_log([:tx_hash, :tx_index])
    |> OmiseGO.API.LoggerHelpers.with_context(%{tx: transaction})
    |> Logger.debug()

    result
  end

  @spec get_block(hash :: bitstring) ::
          {:ok, %{hash: bitstring, transactions: list}} | {:error, :not_found | :internal_error}
  def get_block(hash) do
    result = with {:ok, %Block{hash: ^hash, transactions: transactions}} <- FreshBlocks.get(hash) do
      {:ok, %{hash: hash, transactions: transactions |> Enum.map(& &1.signed_tx.signed_tx_bytes)}}
    end

    Logger.debug(fn ->
        strhash = Base.encode64(hash)
        result = if elem(result, 0) == :ok, do: ":ok", else: "#{inspect result}"
        ">resulted with '#{result}', hash '#{strhash}'"
      end)

    result
  end
end

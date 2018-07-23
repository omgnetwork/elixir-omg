defmodule OmiseGO.API do
  @moduledoc """
  Entrypoint for all the exposed public functions of the child chain API.

  Should handle all the initial processing of requests like state-less validity, decoding/encoding
  (but not transport-specific encoding like hex).
  """

  require Logger

  alias OmiseGO.API.{Core, FeeChecker, FreshBlocks, State}
  use OmiseGO.API.ExposeSpec
  import OmiseGO.API.LoggerHelpers

  @spec submit(transaction :: bitstring) ::
          {:ok, %{tx_hash: bitstring, blknum: integer, tx_index: integer}} | {:error, atom}
  def submit(transaction) do
    result =
      with {:ok, recovered_tx} <- Core.recover_tx(transaction),
           {:ok, fees} <- FeeChecker.transaction_fees(recovered_tx),
           {:ok, {tx_hash, blknum, tx_index}} <- State.exec(recovered_tx, fees) do
        {:ok, %{tx_hash: tx_hash, blknum: blknum, tx_index: tx_index}}
      end

    _ =
      result
      |> log_result([:tx_hash, :tx_index])
      |> with_context(%{tx: transaction})
      |> Logger.debug()

    result
  end

  @spec get_block(hash :: bitstring) ::
          {:ok, %{hash: bitstring, transactions: list, number: integer}} | {:error, :not_found | :internal_error}
  def get_block(hash) do
    result =
      with {:ok, struct_block} <- FreshBlocks.get(hash),
           do: {:ok, Map.from_struct(struct_block)}

    _ =
      result
      |> log_result()
      |> with_context(%{hash: hash})
      |> Logger.debug()

    result
  end
end

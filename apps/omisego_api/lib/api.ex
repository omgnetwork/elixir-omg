defmodule OmiseGO.API do
  @moduledoc """
  Entrypoint for all the exposed public functions of the child chain API
  """

  alias OmiseGO.API.{Core, State, Block}
  alias OmiseGO.API.FreshBlocks
  use OmiseGO.API.ExposeSpec

  @spec submit(transaction :: bitstring) ::
          {:ok, %{tx_hash: bitstring, blknum: integer, tx_index: integer}} | {:error, atom}
  def submit(transaction) do
    with {:ok, recovered_tx} <- Core.recover_tx(transaction),
         {:ok, tx_hash, blknum, tx_index} <- State.exec(recovered_tx) do
      {:ok, %{tx_hash: tx_hash, blknum: blknum, tx_index: tx_index}}
    end
  end

  @spec get_block(hash :: bitstring) ::
          {:ok, %{hash: bitstring, transactions: list}} | {:error, :not_found | :internal_error}
  def get_block(hash) do
    case FreshBlocks.get(hash) do
      {:ok, %Block{hash: ^hash, transactions: transactions}} ->
        {:ok, %{hash: hash, transactions: transactions |> Enum.map(& &1.signed_tx_bytes)}}

      {:error, msg} ->
        {:error, msg}
    end
  end
end

defmodule OmiseGO.API do
  @moduledoc """
  Entrypoint for all the exposed public functions of the child chain API
  """

  alias OmiseGO.API.{Core, State, Block}
  alias OmiseGO.API.FreshBlocks
  alias OmiseGO.DB
  use OmiseGO.API.ExposeSpec

  @spec submit(transaction :: bitstring) ::
          {:ok, %{tx_hash: bitstring, blknum: integer, tx_index: integer}} | {:error, atom}
  def submit(transaction) do
    with {:ok, recovered_tx} <- Core.recover_tx(transaction),
         {:ok, tx_hash, blknum, tx_index} <- State.exec(recovered_tx)
         do
      {:ok, %{tx_hash: tx_hash, blknum: blknum, tx_index: tx_index}}
    end
  end

  @spec get_block(hash :: bitstring) ::
          {:ok, %{hash: bitstring, transactions: list}} | {:error, :not_found | any | :internal_error}
  def get_block(hash) do
    case FreshBlocks.get(hash) do
      %Block{hash: ^hash, transactions: transactions} ->
        {:ok, %{hash: hash, transactions: transactions |> Enum.map(&(&1.signed_tx_bytes))}}

      :not_found ->
        {:error, :not_found}

      {:error, msg} ->
        {:error, msg}

      _ ->
        {:error, :internal_error}
    end
  end

  # TODO: this will likely be dropped from the OmiseGO.API and here
  def tx(hash) do
    DB.tx(hash)
  end
end

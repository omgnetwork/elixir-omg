defmodule OmiseGO.API do
  @moduledoc """
  Entrypoint for all the exposed public functions of the child chain API
  """

  alias OmiseGO.API.State
  alias OmiseGO.API.Core
  alias OmiseGO.API.FreshBlocks
  alias OmiseGO.DB

  use OmiseGO.API.ExposeSpec

  @spec submit(transaction :: String.t()) ::
          {:ok, %{tx_hash: String.t(), blknum: integer, tx_index: integer}} | {:error, atom}
  def submit(transaction) do
    with {:ok, singed_tx} <- decode(transaction),
         {:ok, recovered_tx} <- Core.recover_tx(singed_tx),
         {:ok, tx_hash, blknum, tx_index} <- State.exec(recovered_tx),
         encode_tx_hash <- encode(tx_hash) do
      {:ok, %{tx_hash: encode_tx_hash, blknum: blknum, tx_index: tx_index}}
    end
  end

  @spec get_block(hash :: String.t()) :: {:ok, map | atom} | {:error, atom}
  def get_block(hash) do
    with {:ok, decoded_hash} <- decode(hash),
         {:ok, block} <- FreshBlocks.get(decoded_hash),
         do: {:ok, encode(block)}
  end

  # TODO https://www.pivotaltracker.com/story/show/157423307
  defp encode(arg) when is_binary(arg), do: Base.encode16(arg)

  defp encode(arg) when is_map(arg) do
    arg = Map.from_struct(arg)

    for {key, value} <- arg, into: %{} do
      {key, encode(value)}
    end
  end

  defp encode(arg) when is_list(arg), do: for(value <- arg, into: [], do: encode(value))
  defp encode(arg), do: arg


  # TODO: this will likely be dropped from the OmiseGO.API and here
  def tx(hash) do
    DB.tx(hash)
  defp decode(arg) do
    case Base.decode16(arg) do
      :error -> {:error, :argument_decode_error}
      other -> other
    end
  end
end

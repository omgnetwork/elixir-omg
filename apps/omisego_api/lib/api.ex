defmodule OmiseGO.API do
  @moduledoc """
  Entrypoint for all the exposed public functions of the child chain API
  """

  alias OmiseGO.API.State
  alias OmiseGO.API.Core
  alias OmiseGO.API.FreshBlocks
  alias OmiseGO.DB

  use OmiseGO.API.ExposeSpec

  @spec submit(encoded_signed_tx :: String.t()) ::
          {:ok, %{tx_hash: String.t(), blknum: integer, tx_index: integer}} | :error
  def submit(transaction_hash) do
    with {:ok, encoded_singed_tx} <- decode(transaction_hash),
         {:ok, recovered_tx} <- Core.recover_tx(encoded_singed_tx),
         {:ok, tx_hash, blknum, tx_index} <- State.exec(recovered_tx),
         encode_tx_hash <- decode(tx_hash),
         do: {:ok, %{tx_hash: encode_tx_hash, blknum: blknum, tx_index: tx_index}}
  end

  @spec get_block(hash :: String.t()) :: none | {:ok, any}
  def get_block(encoded_hash) do
    with {:ok, hash} <- decode(encoded_hash), do: {:ok, encode(FreshBlocks.get(hash))}
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

  defp decode(arg), do: Base.decode16(arg)

  # TODO: this will likely be dropped from the OmiseGO.API and here
  def tx(hash) do
    DB.tx(hash)
  end
end

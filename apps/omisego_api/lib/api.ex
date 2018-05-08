defmodule OmiseGO.API do
  @moduledoc """
  Entrypoint for all the exposed public functions of the child chain API
  """

  alias OmiseGO.API.State
  alias OmiseGO.API.Core
  alias OmiseGO.API.FreshBlocks
  alias OmiseGO.DB

  use OmiseGO.API.ExposeSpec

  @spec submit(encoded_signed_tx :: String.t()) :: {:ok, %{tx_hash: String.t(), blknum: integer, tx_index: integer}}
  def submit(transaction_hash) do
    encoded_singed_tx = Base.decode16!(transaction_hash)

    with {:ok, recovered_tx} <- Core.recover_tx(encoded_singed_tx),
         {:ok, tx_hash, blknum, tx_index} <- State.exec(recovered_tx),
         do: {:ok, %{tx_hash: Base.encode64(tx_hash), blknum: blknum, tx_index: tx_index}}
  end

  @spec get_block(hash :: String.t()) :: none | {:ok, any}
  def get_block(hash), do: {:ok, encode(FreshBlocks.get(Base.decode16!(hash)))}

  def encode(arg) when is_binary(arg), do: Base.encode16(arg)

  def encode(arg) when is_map(arg) do
    arg = Map.from_struct(arg)

    for {key, value} <- arg, into: %{} do
      {to_string(key), encode(value)}
    end
  end

  def encode(arg) when is_list(arg), do: for(value <- arg, into: [], do: encode(value))
  def encode(arg), do: arg

  # TODO: this will likely be dropped from the OmiseGO.API and here
  def tx(hash) do
    DB.tx(hash)
  end
end

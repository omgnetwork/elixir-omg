defmodule OmiseGO.API do
  @moduledoc """
  Entrypoint for all the exposed public functions of the child chain API
  """

  alias OmiseGO.API.State
  alias OmiseGO.API.Core
  alias OmiseGO.API.FreshBlocks
  alias OmiseGO.DB

  @spec submit(byte) :: {:ok, integer, integer, byte} | {:error, any}
  def submit(encoded_singed_tx) do
    with {:ok, recovered_tx} <- Core.recover_tx(encoded_singed_tx),
         tx_result <- State.exec(recovered_tx),
         do: tx_result
  end

  def get_block(hash) do
    FreshBlocks.get(hash)
  end

  # TODO: this will likely be dropped from the OmiseGO.API and here
  def tx(hash) do
    DB.tx(hash)
  end
end

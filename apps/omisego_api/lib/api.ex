defmodule OmiseGO.API do
  @moduledoc """
  Entrypoint for all the exposed public functions of the child chain API
  """

  alias OmiseGO.API.State
  alias OmiseGO.API.Core
  alias OmiseGO.DB

  @spec submit(byte) :: {:ok} | {:error, any}
  def submit(encoded_singed_tx) do
    with {:ok, recovered_tx} <- Core.recover_tx(encoded_singed_tx),
        {:ok, _recovered_tx} <- State.exec(recovered_tx),
    do: {:ok}
  end

  def get_block(_height) do
    # BlockCache.get_block(height)
  end

  def tx(hash) do
    DB.tx(hash)
  end

end

defmodule OmiseGO.API do
  @moduledoc """
  Entrypoint for all the exposed public functions of the child chain API
  """

  alias OmiseGO.API.State
  alias OmiseGO.API.Core
  alias OmiseGO.DB

  def submit(tx) do

    # TODO: consider having StatelessValidatonWorker to scale this, instead scaling API
    with {:ok, decoded_tx} <- Core.statelessly_valid?(tx), # stateless validity (EDIT: most likely an ecrecover on sigs)
         tx_result <- State.exec(decoded_tx), # GenServer.call
         do: tx_result
  end

  def get_block(_height) do
    # BlockCache.get_block(height)
  end

  def tx(hash) do
    DB.tx(hash)
  end

  defmodule Core do
    @moduledoc """
    Functional core work-horse for OmiseGO.API
    """
    def statelessly_valid?(_tx) do
      # well formed, signed etc, returns decoded tx
    end
  end

end

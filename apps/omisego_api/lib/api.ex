defmodule OmiseGO.API do
  @moduledoc """
  Entrypoint for all the exposed public functions of the child chain API
  """

  alias OmiseGO.API.State
  alias OmiseGO.API.Core
  alias OmiseGO.DB

  def submit(tx) do

    # FIXME: revert to have the decode tx step
    with tx_result <- State.exec(tx),
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

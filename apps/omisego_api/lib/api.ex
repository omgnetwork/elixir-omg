defmodule OmiseGO.API do
  @moduledoc """
  Entrypoint for all the exposed public functions of the child chain API
  """

  alias OmiseGO.API.State
  alias OmiseGO.API.State.Transaction
  alias OmiseGO.API.Core
  alias OmiseGO.DB

  def submit(encoded_singed_tx) do

    # TODO: consider having StatelessValidatonWorker to scale this, instead scaling API
    with {:ok, recovered_tx} <- Core.recover_tx(encoded_singed_tx),
      recovered_tx <- State.exec(recovered_tx),
    do: {:ok}
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

    alias OmiseGO.API.State.Transaction

    def recover_tx(encoded_singed_tx) do
      with {:ok, singed_tx} <- Transaction.Signed.decode(encoded_singed_tx),
        recovered_tx <- Transaction.Recovered.recover_from(singed_tx),
      do: {:ok, recovered_tx}
    end
    
  end

end

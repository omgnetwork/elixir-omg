defmodule OmiseGO.API do

  def submit(tx) do

    # TODO: consider having StatelessValidatonWorker to scale this, instead scaling API
    with {:ok, decoded_tx} <- Core.statelessly_valid?(tx), # stateless validity
         tx_result <- State.exec(decoded_tx), # GenServer.call
         do: tx_result
  end

  def get_block(height) do
    FreshBlocks.get(height)
  end

  def tx(hash) do
    DB.tx(hash)
  end

  defmodule Core do
    def statelessly_valid?(tx) do
      # well formed, signed etc, returns decoded tx
    end
  end

end

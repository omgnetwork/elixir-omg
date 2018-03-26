defmodule OmiseGO.API.Core do
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

defmodule OmiseGO.API.TestHelper do
  @moduledoc """
  Various shared functions used in API tests
  """

  alias OmiseGO.API.State.Transaction

  @signature <<1>> |> List.duplicate(65) |> :binary.list_to_bin

  def signed(%Transaction{} = tx) do
    Transaction.Signed.hash(
      %Transaction.Signed{raw_tx: tx, sig1: @signature, sig2: @signature}
    )
  end
end

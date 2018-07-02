defmodule OmiseGO.API.FeeChecker do
  @moduledoc """
  Maintains current fee rates and acceptable tokens, updates fees information from external source.
  Provides function to validate transaction's fee.
  """

  alias OmiseGO.API.FeeChecker.Core
  alias OmiseGO.API.State.Transaction.Recovered


  @doc """
  Calculates fee from tx and checks whether token is allowed and both percentage and flat fee limits are met
  """
  @spec transaction_fees(Recovered.t()) ::
          {:ok, map()} | {:error, :token_not_allowed | :fee_too_low}
  def transaction_fees(recovered_tx) do
    Core.transaction_fees(recovered_tx, %{})
  end
end

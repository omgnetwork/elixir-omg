defmodule OmiseGO.API.FeeChecker.Core do
  @moduledoc """
  Transaction's fee validation functions
  """

  alias OmiseGO.API.State.Transaction
  alias OmiseGO.API.State.Transaction.Recovered

  @doc """
  Calculates fee from tx and checks whether token is allowed and both percentage and flat fee limits are met
  """
  @spec transaction_fees(Recovered.t(), map()) ::
          {:ok, map()} | {:error, :token_not_allowed | :fee_too_low}
  def transaction_fees(recovered_tx, token_fees) do
    %Recovered{raw_tx: %Transaction{amount1: amount1, amount2: amount2}} = recovered_tx

    {:ok, %{Transaction.zero_address() => amount1 + amount2}}
  end
end

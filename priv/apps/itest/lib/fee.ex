defmodule Itest.Fee do
  @moduledoc """
  Functions to pull fees
  """

  alias Itest.Client
  alias Itest.Transactions.PaymentType

  @payment_tx_type PaymentType.simple_payment_transaction() |> Binary.to_integer() |> Integer.to_string()

  @doc """
  get all supported fees for payment transactions
  """
  def get_fees() do
    {:ok, %{@payment_tx_type => fees}} = Client.get_fees()
    fees
  end

  @doc """
  get the fee for a specific currency
  """
  def get_for_currency(currency) do
    fees = get_fees()
    Enum.find(fees, &(&1["currency"] == currency))
  end
end

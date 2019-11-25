defmodule Itest.Transactions.PaymentType do
  @moduledoc """
  Return our Payment type
  """

  @simple_payment_transaction <<1>>
  def simple_payment_transaction(), do: @simple_payment_transaction
end

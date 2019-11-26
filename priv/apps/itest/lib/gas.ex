defmodule Itest.Gas do
  @moduledoc """
  Functions to pull gas charges from the transaction hash
  """

  require Logger

  def get_gas_used(receipt_hash) do
    case {Ethereumex.HttpClient.eth_get_transaction_receipt(receipt_hash),
          Ethereumex.HttpClient.eth_get_transaction_by_hash(receipt_hash)} do
      {{:ok, %{"gasUsed" => gas_used}}, {:ok, %{"gasPrice" => gas_price}}} ->
        {gas_price_value, ""} = gas_price |> String.replace_prefix("0x", "") |> Integer.parse(16)
        {gas_used_value, ""} = gas_used |> String.replace_prefix("0x", "") |> Integer.parse(16)
        gas_price_value * gas_used_value

      {{:ok, nil}, {:ok, nil}} ->
        0
    end
  end
end

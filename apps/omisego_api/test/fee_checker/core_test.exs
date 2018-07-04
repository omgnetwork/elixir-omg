defmodule OmiseGO.API.FeeChecker.CoreTest do
  @moduledoc false

  use ExUnit.Case, async: true

  alias OmiseGO.API.State.Transaction
  alias OmiseGO.API.State.Transaction.Recovered

  import OmiseGO.API.FeeChecker.Core

  @valid_currency <<0::size(160)>>
  @invalid_currency <<1::size(160)>>

  defp tx(currency, amount1, amount2) do
    %Recovered{
      raw_tx: %Transaction{
        cur12: currency,
        amount1: amount1,
        amount2: amount2
      }
    }
  end

  describe "Transaction fees" do
    test "flat fee - minimal inputs value is sum of outputs and fee" do
      fees_config = [%{token: @valid_currency, flat_fee: 1}]
      total_with_fee = 3 + 2 + 1

      result = transaction_fees(tx(@valid_currency, 3, 2), fees_config)

      assert {:ok, %{@valid_currency => ^total_with_fee}} = result
    end

    test "allows zero fee - minimal inputs value is sum of outputs" do
      fees_config = [%{token: @valid_currency, flat_fee: 0}]
      total_with_fee = 3 + 2 + 0

      result = transaction_fees(tx(@valid_currency, 3, 2), fees_config)

      assert {:ok, %{@valid_currency => ^total_with_fee}} = result
    end

    test "allows zero fee - swapping currencies" do
      fees_config = [%{token: @invalid_currency, flat_fee: 0}]
      total_with_fee = 3 + 2 + 0

      result = transaction_fees(tx(@invalid_currency, 3, 2), fees_config)

      assert {:ok, %{@invalid_currency => ^total_with_fee}} = result
    end

    test "returns error :token_not_allowed when token is unknown" do
      fees_config = [%{token: @valid_currency, flat_fee: 1}]

      result = transaction_fees(tx(@invalid_currency, 3, 2), fees_config)

      assert {:error, :token_not_allowed} = result
    end
  end
end

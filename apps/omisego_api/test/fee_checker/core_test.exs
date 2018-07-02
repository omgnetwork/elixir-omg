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
    test "transaction validation" do
      assert {:ok, _} = transaction_fees(tx(@valid_currency, 3, 2), %{})
    end

    test "returns error :token_not_allowed when token is unknown" do
      # TODO
    end

    test "returns error :fee_too_low when sum of amounts is less than flat fee" do
      # TODO
    end

    test "allows tx without fee when fee is zero" do
      # TODO
    end

    test "flat fee greater returns minum input based on flat fee" do
      # TODO
    end

    test "total rate fee greater returns minum input based on tx total" do
      # TODO
    end
  end
end

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

  describe "Transaction fees:" do
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

  describe "Parser output:" do
    test "parse valid data is successful" do
      json_output = [
        %{
          "token" => "0x0000000000000000000000000000000000000000",
          "flat_fee" => 2
        },
        %{
          "token" => "0xd26114cd6EE289AccF82350c8d8487fedB8A0C07",
          "flat_fee" => 1,
          # additional keys are ignored
          "name" => "OMG"
        },
        %{
          "token" => "0xa74476443119A942dE498590Fe1f2454d7D4aC0d",
          # zero fee is allowed
          "flat_fee" => 0
        }
      ]

      assert {[], fee_specs} = parse_fee_specs(json_output)
      assert Enum.count(fee_specs) == 3
    end

    test "parse invalid data return errors" do
      json_output = [
        %{
          "invalid_key" => nil,
          "error_reason" => "Providing unexpeced map results with :invalid_fee_spec error"
        },
        %{
          "token" => "0x0000000000000000000000000000000000000000",
          "flat_fee" => -1,
          "error_reason" => "Negative fee results with :invalid_fee error"
        },
        %{
          "token" => "this is not HEX",
          "flat_fee" => 0,
          "error_reason" => "Wrongly formatted token results with :invalid_token error"
        },
        %{
          "token" => "0x0123456789abCdeF",
          "flat_fee" => 1,
          "error_reason" => "Tokens length other than 20 bytes results with :invalid_token error"
        }
      ]

      expected_errors = [
        {{:error, :invalid_fee_spec}, 1},
        {{:error, :invalid_fee}, 2},
        {{:error, :invalid_token}, 3},
        {{:error, :invalid_token}, 4}
      ]

      assert {^expected_errors, _} = parse_fee_specs(json_output)
    end
  end
end

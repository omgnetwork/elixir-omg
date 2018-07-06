defmodule OmiseGO.API.FeeChecker.CoreTest do
  @moduledoc false

  use ExUnit.Case, async: true

  alias OmiseGO.API.State.Transaction
  alias OmiseGO.API.State.Transaction.Recovered

  import OmiseGO.API.FeeChecker.Core

  describe "Transaction fees:" do
    import OmiseGO.API.FeeChecker.Core

    @valid_currency <<0::size(160)>>
    @other_currency <<1::size(160)>>

    defp tx(currency, amount1, amount2) do
      %Recovered{
        raw_tx: %Transaction{
          cur12: currency,
          amount1: amount1,
          amount2: amount2
        }
      }
    end

    # test "flat fee - minimal inputs value is sum of outputs and fee" do
    #   fees_config = [%{token: @valid_currency, flat_fee: 1}]
    #   total_with_fee = 3 + 2 + 1

    #   result = transaction_fees(tx(@valid_currency, 3, 2), fees_config)

    #   assert {:ok, %{@valid_currency => ^total_with_fee}} = result
    # end

    # test "allows zero fee - minimal inputs value is sum of outputs" do
    #   fees_config = [%{token: @valid_currency, flat_fee: 0}]
    #   total_with_fee = 3 + 2 + 0

    #   result = transaction_fees(tx(@valid_currency, 3, 2), fees_config)

    #   assert {:ok, %{@valid_currency => ^total_with_fee}} = result
    # end

    # test "allows zero fee - swapping currencies" do
    #   fees_config = [%{token: @other_currency, flat_fee: 0}]
    #   total_with_fee = 3 + 2 + 0

    #   result = transaction_fees(tx(@other_currency, 3, 2), fees_config)

    #   assert {:ok, %{@other_currency => ^total_with_fee}} = result
    # end

    # test "returns error :token_not_allowed when token is unknown" do
    #   fees_config = [%{token: @valid_currency, flat_fee: 1}]

    #   result = transaction_fees(tx(@other_currency, 3, 2), fees_config)

    #   assert {:error, :token_not_allowed} = result
    # end
  end

  describe "Parser output:" do

    @eth <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0>>
    @fee_config_file ~s(
      [
        { "token": "0x0000000000000000000000000000000000000000", "flat_fee": 2 },
        { "token": "0xd26114cd6EE289AccF82350c8d8487fedB8A0C07", "flat_fee": 0 },
        { "token": "0xa74476443119A942dE498590Fe1f2454d7D4aC0d", "flat_fee": 4 },
        { "token": "0x4156D3342D5c385a87D264F90653733592000581", "flat_fee": 3 },
        { "token": "0x81c9151de0C8bafCd325a57E3dB5a5dF1CEBf79c", "flat_fee": 5 }
      ]
    )

    test "parse valid data is successful" do
      assert {[], fee_map} = parse_file_content(@fee_config_file)

      assert Enum.count(fee_map) == 5

      assert fee_map[@eth] == 2
    end

    test "empty fee spec list is parsed correctly" do
      assert {[], %{}} = parse_file_content("[]")
    end

    test "parse invalid data return errors" do
      json = ~s([
        {
          "invalid_key": null,
          "error_reason": "Providing unexpeced map results with :invalid_fee_spec error"
        },
        {
          "token": "0x0000000000000000000000000000000000000000",
          "flat_fee": -1,
          "error_reason": "Negative fee results with :invalid_fee error"
        },
        {
          "token": "this is not HEX",
          "flat_fee": 0,
          "error_reason": "Wrongly formatted token results with :invalid_token error"
        },
        {
          "token": "0x0123456789abCdeF",
          "flat_fee": 1,
          "error_reason": "Tokens length other than 20 bytes results with :invalid_token error"
        }
      ])

      expected_errors = [
        {{:error, :invalid_fee_spec}, 1},
        {{:error, :invalid_fee}, 2},
        {{:error, :invalid_token}, 3},
        {{:error, :invalid_token}, 4}
      ]

      assert {^expected_errors, _} = parse_file_content(json)
    end

    test "json with duplicate tokens returns error" do
      json = ~s([
        {"token": "0x0000000000000000000000000000000000000000", "flat_fee": 1},
        {"token": "0x0000000000000000000000000000000000000000", "flat_fee": 2}
      ])

      expected_errors = [{{:error, :duplicate_token}, 2}]

      assert {^expected_errors, _} = parse_file_content(json)
    end
  end
end

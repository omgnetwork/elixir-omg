defmodule OmiseGO.API.FeeChecker.ParserTest do
  @moduledoc false

  use ExUnit.Case, async: true

  import OmiseGO.API.FeeChecker

  @fee_config_file ~s(
    [
      { "token": "0x0000000000000000000000000000000000000000", "flat_fee": 2 },
      { "token": "0xd26114cd6EE289AccF82350c8d8487fedB8A0C07", "flat_fee": 0 },
      { "token": "0xa74476443119A942dE498590Fe1f2454d7D4aC0d", "flat_fee": 4 },
      { "token": "0x4156D3342D5c385a87D264F90653733592000581", "flat_fee": 3 },
      { "token": "0x81c9151de0C8bafCd325a57E3dB5a5dF1CEBf79c", "flat_fee": 5 }
    ]
  )

  @eth <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0>>
  @eth_str "0x0000000000000000000000000000000000000000"

  test "Parsing fee config file" do
    assert {:ok, fees} = parse_file_content(@fee_config_file)
    assert is_list(fees)
    assert Enum.count(fees) == 5

    allowed_keys = [:flat_fee, :token]
    fees |> Enum.each(fn map -> assert Map.keys(map) == allowed_keys end)

    eth_spec = fees |> Enum.at(0)
    assert Map.get(eth_spec, :token) == @eth
    assert Map.get(eth_spec, :flat_fee) == 2
  end

  test "Parsing empty fee spec list" do
    assert {:ok, []} = parse_file_content("[]")
  end

  test "Parsing compressed json string" do
    assert {:ok, [%{flat_fee: 0, token: @eth}]} = parse_file_content(~s([{"token":"#{@eth_str}","flat_fee":0}]))
  end

  test "Parsing fee spec - additional keys are ignored" do
    assert {:ok, [%{flat_fee: 1, token: @eth}]} =
             parse_file_content(~s([{"token": "#{@eth_str}", "flat_fee": 1, "name": "eth"}]))
  end

  test "Invalid fee spec - negative fee" do
    assert {:error, :invalid_fee} = parse_file_content(~s([{"token": "#{@eth_str}", "flat_fee": -1}]))
  end

  test "Invalid fee spec - key out of allowed keys" do
    assert {:error, :invalid_fee_spec} = parse_file_content(~s([{"hello": "world!"}]))
  end

  test "Invalid fee spec - invalid base16 token address" do
    assert {:error, :invalid_token} =
             parse_file_content(~s([{"token": "0x0123456789abcdef0000000000000000000000zz", "flat_fee": 1}]))
  end

  test "Invalid fee spec - invalid token wrong size" do
    assert {:error, :invalid_token} =
             parse_file_content(~s([{"token": "0x000000000000000000000000000000000000001", "flat_fee": 1}]))

    assert {:error, :invalid_token} =
             parse_file_content(~s([{"token": "0x00000000000000000000000000000000000000101", "flat_fee": 1}]))
  end
end

defmodule OmiseGO.EthTest do
  alias OmiseGO.Eth, as: Eth
  alias OmiseGO.Eth.WaitFor, as: WaitFor

  use ExUnitFixtures
  use ExUnit.Case, async: false

  #@moduletag :requires_geth

  defp generate_transaction( nonce ) do
    %Eth.Transaction{
        root_hash: "0x" <> (:crypto.hash(:sha256, to_charlist(nonce)) |> Base.encode16),
        gas_price: "0x2D0900",
        nonce: nonce
    }
  end

  defp add_bloks(range, contract) do
      for nonce <- range, do: Eth.submit_block(generate_transaction(nonce),contract.from,contract.addres)
  end

  @tag fixtures: [:contract]
  test "child block increment after add block", %{contract: contract} do
    add_bloks(1..3,contract)
    {:ok, 4} = Eth.get_current_child_block(contract.addres)
  end

  @tag fixtures: [:contract]
  test "child not increment number after add wrong nonce", %{contract: contract} do
     add_bloks(1..3,contract)
    {:ok, current_block} = Eth.get_current_child_block(contract.addres)

     add_bloks(Enum.to_list(1..10) -- [current_block],contract)

    {:ok, ^current_block} = Eth.get_current_child_block(contract.addres)
  end

  @tag fixtures: [:geth]
  test "get_ethereum_heigh return integer" do
    {:ok, number} = Eth.get_ethereum_height()
    assert is_integer(number)
  end

  @tag fixtures: [:contract]
  test "get child chain", %{contract: contract}  do
    add_bloks(1..8, contract)
    block  = generate_transaction(4)
    {:ok, hash} = Eth.get_child_chain(4, contract.addres)
    hash = String.downcase(hash)
    assert String.slice(hash, 0, String.length(block.root_hash)) ==
             String.downcase(block.root_hash)
  end
end

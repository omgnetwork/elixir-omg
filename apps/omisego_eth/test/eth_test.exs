defmodule OmiseGO.EthTest do
  alias OmiseGO.Eth, as: Eth
  alias OmiseGO.Eth.WaitFor, as: WaitFor

  use ExUnitFixtures
  use ExUnit.Case, async: false

  @moduletag :requires_geth

  defp generate_transaction(nonce) do
    hash = :crypto.hash(:sha256, to_charlist(nonce))
    hash = hash |> Base.encode16()

    %Eth.BlockSubmission{
      num: nonce,
      hash: hash,
      gas_price: 20_000_000_000,
      nonce: nonce,
    }
  end

  defp add_bloks(range, contract) do
    for nonce <- range do
      {:ok, txhash} =
        Eth.submit_block(generate_transaction(nonce), contract.from, contract.address)

      WaitFor.eth_receipt(txhash, 10_000)
    end
  end

  @tag fixtures: [:contract]
  test "child block increment after add block", %{contract: contract} do
    add_bloks(1..3, contract)
    {:ok, 4} = Eth.get_current_child_block(contract.address)
  end

  @tag fixtures: [:geth]
  test "get_ethereum_heigh return integer" do
    {:ok, number} = Eth.get_ethereum_height()
    assert is_integer(number)
  end

  @tag fixtures: [:contract]
  test "get child chain", %{contract: contract} do
    add_bloks(1..8, contract)
    block = generate_transaction(4)
    {:ok, {child_chain_hash, _child_chain_time}} = Eth.get_child_chain(4, contract.address)
    assert String.downcase(block.hash) == child_chain_hash |> Base.encode16(case: :lower)
  end
end

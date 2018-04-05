defmodule OmiseGO.EthTest do
  alias OmiseGO.Eth, as: Eth
  alias OmiseGO.Eth.WaitFor, as: WaitFor

  use ExUnitFixtures
  use ExUnit.Case, async: false

  @timeout 10_000

  @moduletag :requires_geth

  defp generate_transaction(nonce) do
    hash = :crypto.hash(:sha256, to_charlist(nonce))
    hash = hash |> Base.encode16()

    %Eth.BlockSubmission{
      num: nonce,
      hash: hash,
      gas_price: 20_000_000_000,
      nonce: nonce
    }
  end

  defp deposit(contract) do
    data = "deposit()" |> ABI.encode([]) |> Base.encode16()
    {:ok, transaction_hash} = Ethereumex.HttpClient.eth_send_transaction(%{
      from: contract.from,
      to: contract.address,
      data: "0x#{data}",
      gas: "0x2D0900",
      gasPrice: "0x1",
      value: "0x1"
    })
    {:ok, _} = WaitFor.eth_receipt(transaction_hash, @timeout)
  end

  defp add_bloks(range, contract) do
    for nonce <- range do
      {:ok, txhash} =
        Eth.submit_block(generate_transaction(nonce), contract.from, contract.address)

      {:ok, _} = WaitFor.eth_receipt(txhash, @timeout)
    end
  end

  @tag fixtures: [:contract]
  test "child block increment after add block", %{contract: contract} do
    add_bloks(1..3, contract)
    {:ok, 4000} = Eth.get_current_child_block(contract.address)
  end

  @tag fixtures: [:geth]
  test "get_ethereum_height return integer" do
    {:ok, number} = Eth.get_ethereum_height()
    assert is_integer(number)
  end

  @tag fixtures: [:contract]
  test "get child chain", %{contract: contract} do
    add_bloks(1..8, contract)
    block = generate_transaction(4)
    {:ok, {child_chain_hash, _child_chain_time}} = Eth.get_child_chain(4000, contract.address)
    assert String.downcase(block.hash) == child_chain_hash |> Base.encode16(case: :lower)
  end

  @tag fixtures: [:contract]
  test "gets deposits from a range of blocks", %{contract: contract} do
    deposit(contract)
    {:ok, height} = Eth.get_ethereum_height()
    assert {:ok, [%{amount: 1, block_height: 1, owner: contract.from}]} ==
      Eth.get_deposits(1, height, contract.address)
  end

  @tag fixtures: [:contract]
  test "get contract deployment height", %{contract: contract} do
    {:ok, number} = Eth.get_root_deployment_height(contract.txhash, contract.address)
    assert is_integer(number)
  end
end

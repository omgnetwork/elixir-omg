defmodule OmiseGO.EthTest do

  alias OmiseGO.Eth, as: Eth
  alias OmiseGO.Eth.WaitFor, as: WaitFor
  alias OmiseGO.API.State.Transaction
  alias OmiseGO.API.Crypto

  use ExUnitFixtures
  use ExUnit.Case, async: false

  @timeout 10_000
  @block_offset 1_000_000_000
  @transaction_offset 10_000

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

  defp deposit(value, gas_price, contract) do
    {:ok, txhash} = Eth.deposit(value, gas_price, contract.from, contract.address)
    {:ok, _} = WaitFor.eth_receipt(txhash, @timeout)
  end

  defp start_deposit_exit(deposit_position, value, gas_price, contract) do
    {:ok, txhash} = Eth.start_deposit_exit(deposit_position, value, gas_price, contract.from, contract.address)
    {:ok, _} = WaitFor.eth_receipt(txhash, @timeout)
  end

  defp start_exit(utxo_position, proof, %Transaction.Signed{raw_tx: raw_tx, sig1: sig1, sig2: sig2} = signed_tx, gas_price, contract) do
    {:ok, txhash} = Eth.start_exit(utxo_position, proof, signed_tx, gas_price, contract.from, contract.address)
    {:ok, _} = WaitFor.eth_receipt(txhash, @timeout)
  end

  defp utxo_position(block_height, txindex, oindex),
    do: @block_offset * block_height + txindex * @transaction_offset + oindex

  defp add_blocks(range, contract) do
    for nonce <- range do
      {:ok, txhash} =
        Eth.submit_block(generate_transaction(nonce), contract.from, contract.address)

      {:ok, _} = WaitFor.eth_receipt(txhash, @timeout)
    end
  end

  @tag fixtures: [:contract]
  test "child block increment after add block", %{contract: contract} do
    add_blocks(1..3, contract)
    {:ok, 4000} = Eth.get_current_child_block(contract.address)
  end

  @tag fixtures: [:geth]
  test "get_ethereum_height return integer" do
    {:ok, number} = Eth.get_ethereum_height()
    assert is_integer(number)
  end

  @tag fixtures: [:contract]
  test "get child chain", %{contract: contract} do
    add_blocks(1..8, contract)
    block = generate_transaction(4)
    {:ok, {child_chain_hash, _child_chain_time}} = Eth.get_child_chain(4000, contract.address)
    assert String.downcase(block.hash) == child_chain_hash |> Base.encode16(case: :lower)
  end

  @tag fixtures: [:contract]
  test "gets deposits from a range of blocks", %{contract: contract} do
    deposit(1, 1, contract)
    {:ok, height} = Eth.get_ethereum_height()
    assert {:ok, [%{amount: 1, blknum: 1, owner: contract.from}]} ==
      Eth.get_deposits(1, height, contract.address)
  end

  @tag fixtures: [:contract]
  test "get contract deployment height", %{contract: contract} do
    {:ok, number} = Eth.get_root_deployment_height(contract.txhash, contract.address)
    assert is_integer(number)
  end

  @tag fixtures: [:contract]
  test "get exits from a range of blocks", %{contract: contract} do
    deposit(1, 1, contract)
    deposit_position = utxo_position(1, 0, 0)

    start_deposit_exit(deposit_position, 1, 1, contract)
    {:ok, height} = Eth.get_ethereum_height()
    assert {:ok, [%{owner: contract.from, blknum: 1, txindex: 0, oindex: 0}]} ==
    Eth.get_exits(1, height, contract.address)
  end
end

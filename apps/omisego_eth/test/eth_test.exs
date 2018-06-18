defmodule OmiseGO.EthTest do

  alias OmiseGO.API.Crypto
  alias OmiseGO.API.TestHelper
  alias OmiseGO.Eth, as: Eth
  alias OmiseGO.Eth.WaitFor, as: WaitFor
  alias OmiseGO.API.State.Transaction
  alias OmiseGOWatcher.UtxoDB

  use ExUnitFixtures
  use ExUnit.Case, async: false

  @timeout 20_000
  @block_offset 1_000_000_000
  @transaction_offset 10_000
  @transaction_merkle_tree_height 16

  @moduletag :integration

  defp generate_transaction(nonce) do
    hash = :crypto.hash(:sha256, to_charlist(nonce))

    %Eth.BlockSubmission{
      num: nonce,
      hash: hash,
      gas_price: 20_000_000_000,
      nonce: nonce
    }
  end

  defp deposit(value, gas_price, contract) do
    {:ok, transaction_hash} = Eth.DevHelpers.deposit(value, gas_price, contract.from, contract.address)
    {:ok, _} = WaitFor.eth_receipt(transaction_hash, @timeout)
  end

  defp start_deposit_exit(deposit_position, value, gas_price, contract) do
    {:ok, txhash} = Eth.start_deposit_exit(deposit_position, value, gas_price, contract.from, contract.address)
    {:ok, _} = WaitFor.eth_receipt(txhash, @timeout)
  end

  defp start_exit(utxo_position, txbytes, proof, sigs, gas_price, contract) do
    {:ok, txhash} = Eth.start_exit(utxo_position, txbytes, proof, sigs, gas_price, contract.from, contract.address)
    {:ok, _} = WaitFor.eth_receipt(txhash, @timeout)
  end

  defp utxo_position(block_height, txindex, oindex),
    do: @block_offset * block_height + txindex * @transaction_offset + oindex

  defp add_blocks(range, contract) do
    for nonce <- range do
      {:ok, txhash} = Eth.submit_block(generate_transaction(nonce), contract.from, contract.address)
      {:ok, _receipt} = WaitFor.eth_receipt(txhash, @timeout)
      {:ok, next_num} = Eth.get_current_child_block(contract.address)
      assert next_num == (nonce + 1) * 1000
    end
  end

  @tag fixtures: [:contract]
  test "child block increment after add block", %{contract: contract} do
    add_blocks(1..4, contract)
    # current child block is a num of the next operator block:
    {:ok, 5000} = Eth.get_current_child_block(contract.address)
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
    {:ok, 8000} = Eth.get_mined_child_block(contract.address)
    {:ok, {child_chain_hash, _child_chain_time}} = Eth.get_child_chain(4000, contract.address)
    assert block.hash == child_chain_hash
  end

  @tag fixtures: [:contract]
  test "gets deposits from a range of blocks", %{contract: contract} do
  # deposit(1, 1, contract)
    {:ok, height} = Eth.get_ethereum_height()

    assert {:ok, [%{amount: 1, blknum: 1, owner: contract.from}]} == Eth.get_deposits(1, height, contract.address)
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

  @tag fixtures: [:contract]
  test "get mined block number", %{contract: contract} do
    {:ok, number} = Eth.get_mined_child_block(contract.address)
    assert is_integer(number)
  end

  @tag fixtures: [:contract]
  test "get authority for deployed contract", %{contract: contract} do
    {:ok, addr} = Eth.authority(contract.address)
    assert contract.from == "0x" <> Base.encode16(addr, case: :lower)
  end
end

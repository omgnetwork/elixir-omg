defmodule OmiseGO.EthTest do
  @moduledoc """
  Thin smoke test of the Ethereum port/adapter.
  """
  # TODO: if proves to be brittle and we cover that functionality in other integration test then consider removing

  alias OmiseGO.API.Crypto
  alias OmiseGO.Eth, as: Eth
  alias OmiseGO.Eth.WaitFor, as: WaitFor
  alias OmiseGO.API.State.Transaction
  alias OmiseGOWatcher.UtxoDB

  use ExUnitFixtures
  use ExUnit.Case, async: false
  use OmiseGO.API.Fixtures

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
    {:ok, transaction_hash} = Eth.DevHelpers.deposit(value, gas_price, contract.authority_addr, contract.contract_addr)
    {:ok, _} = WaitFor.eth_receipt(transaction_hash, @timeout)
  end

  defp start_deposit_exit(deposit_position, value, gas_price, contract) do
    {:ok, txhash} =
      Eth.start_deposit_exit(deposit_position, value, gas_price, contract.authority_addr, contract.contract_addr)

    {:ok, _} = WaitFor.eth_receipt(txhash, @timeout)
  end

  defp start_exit(utxo_position, txbytes, proof, sigs, gas_price, contract) do
    {:ok, txhash} =
      Eth.start_exit(utxo_position, txbytes, proof, sigs, gas_price, contract.authority_addr, contract.contract_addr)

    {:ok, _} = WaitFor.eth_receipt(txhash, @timeout)
  end

  defp utxo_position(block_height, txindex, oindex),
    do: @block_offset * block_height + txindex * @transaction_offset + oindex

  defp add_blocks(range, contract) do
    for nonce <- range do
      {:ok, txhash} = Eth.submit_block(generate_transaction(nonce), contract.authority_addr, contract.contract_addr)
      {:ok, _receipt} = WaitFor.eth_receipt(txhash, @timeout)
      {:ok, next_num} = Eth.get_current_child_block(contract.contract_addr)
      assert next_num == (nonce + 1) * 1000
    end
  end

  @tag fixtures: [:contract, :alice, :bob]
  test "start_exit", %{contract: contract, alice: alice, bob: bob} do
    raw_tx = %OmiseGO.API.State.Transaction{
      amount1: 8,
      amount2: 3,
      blknum1: 1,
      blknum2: 0,
      fee: 0,
      newowner1: bob.addr,
      newowner2: alice.addr,
      oindex1: 0,
      oindex2: 0,
      txindex1: 0,
      txindex2: 0
    }

    signed_tx = Transaction.sign(raw_tx, bob.priv, alice.priv)

    {:ok, %Transaction.Recovered{raw_tx: raw_tx, signed_tx_hash: signed_tx_hash}} =
      Transaction.Recovered.recover_from(signed_tx)

    {:ok, mt} = MerkleTree.new([signed_tx_hash], &Crypto.hash/1, @transaction_merkle_tree_height)

    {:ok, child_blknum} = Eth.get_current_child_block(contract.contract_addr)

    block = %Eth.BlockSubmission{
      num: 1,
      hash: mt.root.value,
      gas_price: 20_000_000_000,
      nonce: 1
    }

    Eth.submit_block(block, contract.authority_addr, contract.contract_addr)

    txs = [Map.merge(raw_tx, %{txindex: 0, txid: signed_tx_hash, sig1: signed_tx.sig1, sig2: signed_tx.sig2})]

    %{utxo_pos: utxo_pos, tx_bytes: tx_bytes, proof: proof, sigs: sigs} =
      UtxoDB.compose_utxo_exit(txs, child_blknum * @block_offset, 0, 0)

    {:ok, _} = start_exit(utxo_pos, tx_bytes, proof, sigs, 1, contract)

    # IO.inspect Eth.get_exit(utxo_pos, contract.contract_addr)
    # TODO add assert Eth.get_exit(child_blknum * @block_offset, contract.address) , Currently ABI library is broken
  end

  @tag fixtures: [:contract]
  test "child block increment after add block", %{contract: contract} do
    add_blocks(1..4, contract)
    # current child block is a num of the next operator block:
    {:ok, 5000} = Eth.get_current_child_block(contract.contract_addr)
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
    {:ok, 8000} = Eth.get_mined_child_block(contract.contract_addr)
    {:ok, {child_chain_hash, _child_chain_time}} = Eth.get_child_chain(4000, contract.contract_addr)
    assert block.hash == child_chain_hash
  end

  @tag fixtures: [:contract]
  test "gets deposits from a range of blocks", %{contract: contract} do
    deposit(1, 1, contract)
    {:ok, height} = Eth.get_ethereum_height()

    assert {:ok, [%{amount: 1, blknum: 1, owner: contract.authority_addr}]} ==
             Eth.get_deposits(1, height, contract.contract_addr)
  end

  @tag fixtures: [:contract]
  test "get contract deployment height", %{contract: contract} do
    {:ok, number} = Eth.get_root_deployment_height(contract.txhash_contract, contract.contract_addr)
    assert is_integer(number)
  end

  @tag fixtures: [:contract]
  test "get exits from a range of blocks", %{contract: contract} do
    deposit(1, 1, contract)
    deposit_position = utxo_position(1, 0, 0)

    start_deposit_exit(deposit_position, 1, 1, contract)
    {:ok, height} = Eth.get_ethereum_height()

    assert {:ok, [%{owner: contract.authority_addr, blknum: 1, txindex: 0, oindex: 0, amount: 1}]} ==
             Eth.get_exits(1, height, contract.contract_addr)
  end

  @tag fixtures: [:contract]
  test "get mined block number", %{contract: contract} do
    {:ok, number} = Eth.get_mined_child_block(contract.contract_addr)
    assert is_integer(number)
  end

  @tag fixtures: [:contract]
  test "get authority for deployed contract", %{contract: contract} do
    {:ok, addr} = Eth.authority(contract.contract_addr)
    assert contract.authority_addr == "0x" <> Base.encode16(addr, case: :lower)
  end
end

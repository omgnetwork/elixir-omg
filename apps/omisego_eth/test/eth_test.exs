defmodule OmiseGO.EthTest do

  alias OmiseGO.Eth, as: Eth
  alias OmiseGO.Eth.WaitFor, as: WaitFor
  alias OmiseGO.API.State.Transaction
  alias OmiseGO.API.Crypto
  alias OmiseGOWatcher.UtxoDB
  alias OmiseGO.API.TestHelper

  use ExUnitFixtures
  use ExUnit.Case, async: false

  @timeout 10_000
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

  @tag fixtures: [:contract]
  test "start_exit", %{contract: contract} do

    # TODO clean alice and bob
    alice = %{
      priv:
        <<54, 43, 207, 67, 140, 160, 190, 135, 18, 162, 70, 120, 36, 245, 106, 165,
          5, 101, 183, 55, 11, 117, 126, 135, 49, 50, 12, 228, 173, 219, 183, 175>>,
      addr:
        <<59, 159, 76, 29, 210, 110, 11, 229, 147, 55, 59, 29, 54, 206, 226, 0,
          140, 190, 184, 55>>
    }
    bob = %{
      priv:
        <<208, 253, 134, 150, 198, 155, 175, 125, 158, 156, 21, 108, 208, 7, 103, 242, 9, 139,
          26, 140, 118, 50, 144, 21, 226, 19, 156, 2, 210, 97, 84, 128>>,
      addr:
        <<207, 194, 79, 222, 88, 128, 171, 217, 153, 41, 195, 239, 138, 178, 227, 16, 72, 173,
          118, 35>>
    }

    raw_tx = %OmiseGO.API.State.Transaction{
      amount1: 8,
      amount2: 3,
      blknum1: 0,
      blknum2: 0,
      fee: 0,
      newowner1: bob.addr,
      newowner2: alice.addr,
      oindex1: 0,
      oindex2: 0,
      txindex1: 0,
      txindex2: 0
    }

    singed_tx = Transaction.sign(raw_tx, bob.priv, alice.priv)

    %Transaction.Recovered{raw_tx: raw_tx, signed_tx_hash: signed_tx_hash} = Transaction.Recovered.recover_from(singed_tx)

    {:ok, mt} = MerkleTree.new([signed_tx_hash], &Crypto.hash/1, @transaction_merkle_tree_height)

    {:ok, child_blknum} = Eth.get_current_child_block(contract.address)
    block = %Eth.BlockSubmission{
      num: child_blknum,
      hash: mt.root.value,
      gas_price: 20_000_000_000,
      nonce: 1
    }

    assert child_blknum == 1000

    IO.inspect "root"
    IO.inspect mt.root.value

    Eth.submit_block(block, contract.from, contract.address)

    txs = [Map.merge(raw_tx, %{ txindex: 0, txid: signed_tx_hash})]

    %{
      utxo_pos: utxo_pos,
      tx_bytes: tx_bytes,
      proof: proof } = UtxoDB.compose_utxo_exit(txs, 1000000000, 10000*0, 0)

    sigs = singed_tx.sig1 <> singed_tx.sig2

    IO.inspect tx_bytes,limit: :infinity
    IO.inspect proof, limit: :infinity
    IO.inspect sigs,limit: :infinity

    {:ok, _} = start_exit(1000000000 + 10000*0 + 0, tx_bytes, proof, sigs, 1, contract)

    {:ok, height} = Eth.get_ethereum_height()

    IO.inspect height

    IO.inspect Eth.get_exit(1000000000, contract.address)
    IO.inspect Eth.get_exits(1, height, contract.address)
    IO.inspect Eth.get_current_child_block(contract.address)
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

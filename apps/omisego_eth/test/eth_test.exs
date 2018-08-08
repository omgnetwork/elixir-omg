defmodule OmiseGO.EthTest do
  @moduledoc """
  Thin smoke test of the Ethereum port/adapter.

  Note the excluded moduletag, this test requires an explicit `--include`
  """
  # TODO: if proves to be brittle and we cover that functionality in other integration test then consider removing

  alias OmiseGO.API.Block
  alias OmiseGO.API.Crypto
  alias OmiseGO.API.Utxo
  require Utxo
  alias OmiseGO.Eth, as: Eth
  alias OmiseGO.Eth.WaitFor, as: WaitFor
  alias OmiseGO.API.State.Transaction
  alias OmiseGOWatcher.UtxoDB

  use ExUnitFixtures
  use ExUnit.Case, async: false
  use OmiseGO.API.Fixtures

  @timeout 20_000

  @eth Crypto.zero_address()

  @moduletag :wrappers

  defp generate_transaction(nonce) do
    hash = :crypto.hash(:sha256, to_charlist(nonce))

    %Eth.BlockSubmission{
      num: nonce,
      hash: hash,
      gas_price: 20_000_000_000,
      nonce: nonce
    }
  end

  defp eth_str do
    "0x" <> String.duplicate("00", 20)
  end

  defp deposit(contract) do
    {:ok, txhash} = Eth.DevHelpers.deposit(1, contract.authority_addr, contract.contract_addr)
    {:ok, %{"status" => "0x1"}} = WaitFor.eth_receipt(txhash, @timeout)
  end

  defp start_exit(utxo_position, txbytes, proof, sigs, gas_price, from, contract) do
    {:ok, txhash} = Eth.start_exit(utxo_position, txbytes, proof, sigs, gas_price, from, contract)

    {:ok, _} = WaitFor.eth_receipt(txhash, @timeout)
  end

  defp exit_deposit(contract) do
    deposit_pos = Utxo.position(1, 0, 0) |> Utxo.Position.encode()

    data = "startDepositExit(uint256,address,uint256)" |> ABI.encode([deposit_pos, @eth, 1]) |> Base.encode16()

    {:ok, transaction_hash} =
      Ethereumex.HttpClient.eth_send_transaction(%{
        from: contract.authority_addr,
        to: contract.contract_addr,
        data: "0x#{data}",
        gas: "0x2D0900"
      })

    {:ok, _} = WaitFor.eth_receipt(transaction_hash, @timeout)
  end

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
    {:ok, bob_address} = Eth.DevHelpers.import_unlock_fund(bob)

    raw_tx = %Transaction{
      amount1: 8,
      amount2: 3,
      blknum1: 1,
      blknum2: 0,
      newowner1: bob.addr,
      newowner2: alice.addr,
      cur12: @eth,
      oindex1: 0,
      oindex2: 0,
      txindex1: 0,
      txindex2: 0
    }

    signed_tx = Transaction.sign(raw_tx, bob.priv, alice.priv)

    {:ok,
     %Transaction.Recovered{signed_tx: %Transaction.Signed{raw_tx: raw_tx}, signed_tx_hash: signed_tx_hash} =
       recovered_tx} = Transaction.Recovered.recover_from(signed_tx)

    block = Block.hashed_txs_at([recovered_tx], 1000)

    {:ok, txhash} =
      %Eth.BlockSubmission{
        num: 1000,
        hash: block.hash,
        gas_price: 20_000_000_000,
        nonce: 1
      }
      |> Eth.submit_block(contract.authority_addr, contract.contract_addr)

    {:ok, _} = WaitFor.eth_receipt(txhash, @timeout)

    txs = [Map.merge(raw_tx, %{txindex: 0, txid: signed_tx_hash, sig1: signed_tx.sig1, sig2: signed_tx.sig2})]

    {:ok, child_blknum} = Eth.get_mined_child_block(contract.contract_addr)

    # TODO re: brittleness and dirtyness of this - test requires UtxoDB calls,
    # duplicates our integrations tests - another reason to drop or redesign eth_test.exs sometime
    %{utxo_pos: utxo_pos, txbytes: txbytes, proof: proof, sigs: sigs} =
      UtxoDB.compose_utxo_exit(txs, Utxo.position(child_blknum, 0, 0))

    {:ok, _} = start_exit(utxo_pos, txbytes, proof, sigs, 1, bob_address, contract.contract_addr)

    {:ok, height} = Eth.get_ethereum_height()

    utxo_pos = Utxo.position(1000, 0, 0) |> Utxo.Position.encode()

    assert {:ok, [%{amount: 8, owner: bob_address, utxo_pos: utxo_pos, token: @eth}]} ==
             Eth.get_exits(1, height, contract.contract_addr)
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
    deposit(contract)
    {:ok, height} = Eth.get_ethereum_height()

    assert {:ok, [%{amount: 1, blknum: 1, owner: contract.authority_addr, currency: eth_str()}]} ==
             Eth.get_deposits(1, height, contract.contract_addr)
  end

  @tag fixtures: [:contract]
  test "get contract deployment height", %{contract: contract} do
    {:ok, number} = Eth.get_root_deployment_height(contract.txhash_contract, contract.contract_addr)
    assert is_integer(number)
  end

  @tag fixtures: [:contract]
  test "get exits from a range of blocks", %{contract: contract} do
    deposit(contract)
    exit_deposit(contract)
    {:ok, height} = Eth.get_ethereum_height()

    utxo_pos = Utxo.position(1, 0, 0) |> Utxo.Position.encode()

    assert(
      {:ok, [%{owner: contract.authority_addr, utxo_pos: utxo_pos, token: @eth, amount: 1}]} ==
        Eth.get_exits(1, height, contract.contract_addr)
    )
  end

  @tag fixtures: [:contract]
  test "get mined block number", %{contract: contract} do
    {:ok, number} = Eth.get_mined_child_block(contract.contract_addr)
    assert is_integer(number)
  end

  @tag fixtures: [:contract]
  test "get authority for deployed contract", %{contract: contract} do
    {:ok, addr} = Eth.authority(contract.contract_addr)
    {:ok, encoded_addr} = Crypto.encode_address(addr)
    assert contract.authority_addr == encoded_addr
  end
end

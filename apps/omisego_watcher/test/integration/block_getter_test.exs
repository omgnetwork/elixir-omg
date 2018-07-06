defmodule OmiseGOWatcher.BlockGetterTest do
  use ExUnitFixtures
  use ExUnit.Case, async: false
  use OmiseGO.API.Fixtures
  use Plug.Test

  alias OmiseGO.API.State.Transaction
  alias OmiseGO.Eth
  alias OmiseGO.JSONRPC.Client
  alias OmiseGOWatcher.Integration.TestHelper, as: IntegrationTest
  alias OmiseGOWatcher.TestHelper, as: Test

  @moduletag :integration

  @timeout 20_000
  @block_offset 1_000_000_000
  @zero_address <<0::size(160)>>

  @tag fixtures: [:watcher_sandbox, :config_map, :geth, :child_chain, :root_chain_contract_config, :alice, :bob]
  test "get the blocks from child chain after transaction and start exit", %{
    config_map: config,
    alice: alice,
    bob: bob
  } do
    IntegrationTest.start_block_getter(config)

    deposit_blknum = IntegrationTest.deposit_to_child_chain(alice, 10, config)
    raw_tx = Transaction.new([{deposit_blknum, 0, 0}], Transaction.zero_address(), [{alice.addr, 7}, {bob.addr, 3}])
    tx = raw_tx |> Transaction.sign(alice.priv, <<>>) |> Transaction.Signed.encode()

    {:ok, %{"blknum" => block_nr}} = Client.call(:submit, %{transaction: tx})

    IntegrationTest.wait_until_block_getter_fetches_block(block_nr, @timeout)

    encode_tx = Client.encode(tx)

    assert [%{"amount" => 3, "blknum" => block_nr, "oindex" => 0, "txindex" => 0, "txbytes" => encode_tx}] ==
             get_utxo(bob.addr)

    assert [%{"amount" => 7, "blknum" => block_nr, "oindex" => 0, "txindex" => 0, "txbytes" => encode_tx}] ==
             get_utxo(alice.addr)

    %{
      utxo_pos: utxo_pos,
      tx_bytes: tx_bytes,
      proof: proof,
      sigs: sigs
    } = IntegrationTest.compose_utxo_exit(block_nr, 0, 0)

    alice_address = "0x" <> Base.encode16(alice.addr, case: :lower)

    {:ok, txhash} =
      Eth.start_exit(
        utxo_pos * @block_offset,
        tx_bytes,
        proof,
        sigs,
        1,
        alice_address,
        config.contract_addr
      )

    {:ok, _} = Eth.WaitFor.eth_receipt(txhash, @timeout)

    {:ok, height} = Eth.get_ethereum_height()

    assert {:ok, [%{amount: 7, blknum: block_nr, oindex: 0, owner: alice_address, txindex: 0, token: @zero_address}]} ==
             Eth.get_exits(0, height, config.contract_addr)
  end

  defp get_utxo(address) do
    decoded_resp = Test.rest_call(:get, "account/utxo?address=#{Client.encode(address)}")
    decoded_resp["utxos"]
  end
end

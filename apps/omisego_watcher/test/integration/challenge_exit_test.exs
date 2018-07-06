defmodule OmiseGOWatcher.ChallengeExitTest do
  use ExUnitFixtures
  use ExUnit.Case, async: false
  use OmiseGO.API.Fixtures
  use Plug.Test

  alias OmiseGO.API.State.Transaction
  alias OmiseGO.Eth
  alias OmiseGO.JSONRPC.Client
  alias OmiseGOWatcher.TestHelper, as: Test

  @moduletag :integration

  @timeout 20_000
  @block_offset 1_000_000_000
  @zero_address <<0::size(160)>>

  defp deposit_to_child_chain(to, value, config) do
    {:ok, destiny_enc} = Eth.DevHelpers.import_unlock_fund(to)
    {:ok, deposit_tx_hash} = Eth.DevHelpers.deposit(value, 0, destiny_enc, config.contract_addr)
    {:ok, receipt} = Eth.WaitFor.eth_receipt(deposit_tx_hash)
    deposit_blknum = Eth.DevHelpers.deposit_blknum_from_receipt(receipt)

    post_deposit_child_block =
      deposit_blknum - 1 + (config.ethereum_event_block_finality_margin + 1) * config.child_block_interval

    {:ok, _} = Eth.DevHelpers.wait_for_current_child_block(post_deposit_child_block, true, 60_000, config.contract_addr)

    deposit_blknum
  end

  @tag fixtures: [:watcher_sandbox, :config_map, :geth, :child_chain, :root_chain_contract_config, :alice, :bob]
  test "get the blocks from child chain after transaction and start exit", %{
    config_map: config_map,
    alice: alice,
    bob: bob
  } do
    {:ok, _pid} =
      GenServer.start_link(
        OmiseGOWatcher.BlockGetter,
        %{contract_address: config_map.contract_addr},
        name: BlockGetter
      )

    deposit_blknum = deposit_to_child_chain(alice, 10, config_map)
    raw_tx = Transaction.new([{deposit_blknum, 0, 0}], Transaction.zero_address(), [{alice.addr, 7}, {bob.addr, 3}])
    tx = raw_tx |> Transaction.sign(alice.priv, <<>>) |> Transaction.Signed.encode()

    {:ok, %{"blknum" => exiting_utxo_block_nr}} = Client.call(:submit, %{transaction: tx})

    block_nr = exiting_utxo_block_nr

    raw_tx2 = Transaction.new([{block_nr, 0, 0}], Transaction.zero_address(), [{alice.addr, 4}, {bob.addr, 3}])
    tx2 = raw_tx2 |> Transaction.sign(alice.priv, <<>>) |> Transaction.Signed.encode()

    {:ok, %{"blknum" => block_nr}} = Client.call(:submit, %{transaction: tx2})

    fn ->
      Eth.WaitFor.repeat_until_ok(fn ->
        case GenServer.call(BlockGetter, :get_height) < block_nr do
          true -> :repeat
          false -> {:ok, block_nr}
        end
      end)
    end
    |> Task.async()
    |> Task.await(@timeout)

    Client.call(:submit, %{transaction: tx2})

    challenge = get_exit_challenge(exiting_utxo_block_nr, 0, 0)

    %{
      tx_bytes: tx_bytes,
      proof: proof,
      sigs: sigs
    } = compose_utxo_exit(block_nr, 0, 0)

    alice_address = "0x" <> Base.encode16(alice.addr, case: :lower)

    {:ok, txhash} =
      Eth.start_exit(
        2000 * @block_offset,
        tx_bytes,
        proof,
        sigs,
        1,
        alice_address,
        config_map.contract_addr
      )

    {:ok, _} = Eth.WaitFor.eth_receipt(txhash, @timeout)

    {:ok, height} = Eth.get_ethereum_height()

    assert {:ok, [%{amount: 7, blknum: 2000, oindex: 0, owner: alice_address, txindex: 0, token: @zero_address}]} ==
             Eth.get_exits(0, height, config_map.contract_addr)

    {:ok, txhash} = OmiseGO.Eth.DevHelpers.challenge_exit(challenge.cutxopos, challenge.eutxoindex,
     challenge.txbytes, challenge.proof, challenge.sigs, 1, alice_address, config_map.contract_addr)
     {:ok, %{"status" => "0x1"}} = Eth.WaitFor.eth_receipt(txhash, @timeout)
  end

  defp get_exit_challenge(blknum, txindex, oindex) do
    decoded_resp = Test.rest_call(:get, "challenges?utxo=#{Test.utxo_pos(blknum, txindex, oindex)}")
    {:ok, txbytes} = Client.decode(:bitstring, decoded_resp["txbytes"])
    {:ok, proof} = Client.decode(:bitstring, decoded_resp["proof"])
    {:ok, sigs} = Client.decode(:bitstring, decoded_resp["sigs"])

    %{
      cutxopos: decoded_resp["cutxopos"],
      eutxoindex: decoded_resp["eutxoindex"],
      txbytes: txbytes,
      proof: proof,
      sigs: sigs
    }
  end

  defp compose_utxo_exit(block_height, txindex, oindex) do
    decoded_resp =
      Test.rest_call(:get, "account/utxo/compose_exit?block_height=#{block_height}&txindex=#{txindex}&oindex=#{oindex}")

    {:ok, tx_bytes} = Client.decode(:bitstring, decoded_resp["tx_bytes"])
    {:ok, proof} = Client.decode(:bitstring, decoded_resp["proof"])
    {:ok, sigs} = Client.decode(:bitstring, decoded_resp["sigs"])

    %{
      utxo_pos: decoded_resp["utxo_pos"],
      tx_bytes: tx_bytes,
      proof: proof,
      sigs: sigs
    }
  end
end

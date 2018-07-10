defmodule OmiseGOWatcher.ChallengeExitTest do
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
  @zero_address <<0>> |> List.duplicate(20) |> Enum.reduce(&<>/2)

  @tag fixtures: [:watcher_sandbox, :config_map, :geth, :child_chain, :root_chain_contract_config, :alice, :bob]
  test "challenges invalid exit", %{
    config_map: config,
    alice: alice,
    bob: bob
  } do
    deposit_blknum = IntegrationTest.deposit_to_child_chain(alice, 10, config)
    raw_tx = Transaction.new([{deposit_blknum, 0, 0}], Transaction.zero_address(), [{alice.addr, 7}, {bob.addr, 3}])
    tx = raw_tx |> Transaction.sign(alice.priv, <<>>) |> Transaction.Signed.encode()
    {:ok, %{"blknum" => exiting_utxo_block_nr}} = Client.call(:submit, %{transaction: tx})

    block_nr = exiting_utxo_block_nr

    raw_tx2 = Transaction.new([{block_nr, 0, 0}], Transaction.zero_address(), [{alice.addr, 4}, {bob.addr, 3}])
    tx2 = raw_tx2 |> Transaction.sign(alice.priv, <<>>) |> Transaction.Signed.encode()
    {:ok, %{"blknum" => block_nr}} = Client.call(:submit, %{transaction: tx2})

    IntegrationTest.wait_until_block_getter_fetches_block(block_nr, @timeout)

    %{
      tx_bytes: tx_bytes,
      proof: proof,
      sigs: sigs
    } = IntegrationTest.compose_utxo_exit(block_nr, 0, 0)

    alice_address = "0x" <> Base.encode16(alice.addr, case: :lower)

    utxo_pos = Test.utxo_pos(block_nr, 0, 0)

    {:ok, txhash} =
      Eth.start_exit(
        utxo_pos,
        tx_bytes,
        proof,
        sigs,
        1,
        alice_address,
        config.contract_addr
      )

    {:ok, _} = Eth.WaitFor.eth_receipt(txhash, @timeout)

    challenge = get_exit_challenge(exiting_utxo_block_nr, 0, 0)
    assert {:ok, {alice.addr, @zero_address, 7}} == Eth.get_exit(utxo_pos, config.contract_addr)

    {:ok, txhash} =
      OmiseGO.Eth.DevHelpers.challenge_exit(
        challenge.cutxopos,
        challenge.eutxoindex,
        challenge.txbytes,
        challenge.proof,
        challenge.sigs,
        1,
        alice_address,
        config.contract_addr
      )

    {:ok, %{"status" => "0x1"}} = Eth.WaitFor.eth_receipt(txhash, @timeout)
    assert {:ok, {@zero_address, @zero_address, 7}} == Eth.get_exit(utxo_pos, config.contract_addr)
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
end

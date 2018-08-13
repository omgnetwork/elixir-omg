defmodule OmiseGOWatcher.ChallengeExitTest do
  use ExUnitFixtures
  use ExUnit.Case, async: false
  use OmiseGO.API.Fixtures
  use OmiseGO.API.Integration.Fixtures

  use Plug.Test

  alias OmiseGO.API
  alias OmiseGO.API.Crypto
  alias OmiseGO.Eth
  alias OmiseGO.JSONRPC.Client
  alias OmiseGOWatcher.Integration.TestHelper, as: IntegrationTest
  alias OmiseGOWatcher.TestHelper, as: Test

  @moduletag :integration

  @timeout 20_000
  @zero_address Crypto.zero_address()
  @eth @zero_address

  @tag fixtures: [:watcher_sandbox, :child_chain, :alice, :alice_deposits]
  test "exit eth, with challenging an invalid exit", %{alice: alice, alice_deposits: {deposit_blknum, _}} do
    # NOTE: we're explicitly skipping erc20 challenges here, because eth and erc20 exits/challenges work the exact same
    #       way, so the integration is tested with the eth test

    tx = API.TestHelper.create_encoded([{deposit_blknum, 0, 0, alice}], @eth, [{alice, 10}])
    {:ok, %{blknum: exiting_utxo_block_nr}} = Client.call(:submit, %{transaction: tx})

    IntegrationTest.wait_until_block_getter_fetches_block(exiting_utxo_block_nr, @timeout)

    tx2 = API.TestHelper.create_encoded([{exiting_utxo_block_nr, 0, 0, alice}], @eth, [{alice, 10}])
    {:ok, %{blknum: double_spend_block_nr}} = Client.call(:submit, %{transaction: tx2})

    IntegrationTest.wait_until_block_getter_fetches_block(double_spend_block_nr, @timeout)

    %{
      txbytes: txbytes,
      proof: proof,
      sigs: sigs,
      utxo_pos: utxo_pos
    } = IntegrationTest.compose_utxo_exit(exiting_utxo_block_nr, 0, 0)

    {:ok, alice_address} = Crypto.encode_address(alice.addr)

    {:ok, txhash} =
      Eth.start_exit(
        utxo_pos,
        txbytes,
        proof,
        sigs,
        1,
        alice_address
      )

    {:ok, %{"status" => "0x1"}} = Eth.WaitFor.eth_receipt(txhash, @timeout)

    # after a successful invalid exit starting, the Watcher should be able to assist in successful challenging
    challenge = get_exit_challenge(exiting_utxo_block_nr, 0, 0)
    assert {:ok, {alice.addr, @eth, 10}} == Eth.get_exit(utxo_pos)

    {:ok, txhash} =
      OmiseGO.Eth.DevHelpers.challenge_exit(
        challenge.cutxopos,
        challenge.eutxoindex,
        challenge.txbytes,
        challenge.proof,
        challenge.sigs,
        alice_address
      )

    {:ok, %{"status" => "0x1"}} = Eth.WaitFor.eth_receipt(txhash, @timeout)
    assert {:ok, {@zero_address, @eth, 10}} == Eth.get_exit(utxo_pos)
  end

  defp get_exit_challenge(blknum, txindex, oindex) do
    decoded_resp = Test.rest_call(:get, "challenges?blknum=#{blknum}&txindex=#{txindex}&oindex=#{oindex}")
    {:ok, txbytes} = Base.decode16(decoded_resp["txbytes"], case: :mixed)
    {:ok, proof} = Base.decode16(decoded_resp["proof"], case: :mixed)
    {:ok, sigs} = Base.decode16(decoded_resp["sigs"], case: :mixed)

    %{
      cutxopos: decoded_resp["cutxopos"],
      eutxoindex: decoded_resp["eutxoindex"],
      txbytes: txbytes,
      proof: proof,
      sigs: sigs
    }
  end
end

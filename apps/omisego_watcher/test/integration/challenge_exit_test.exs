defmodule OmiseGOWatcher.ChallengeExitTest do
  use ExUnitFixtures
  use ExUnit.Case, async: false
  use OmiseGO.API.Fixtures
  use Plug.Test

  alias OmiseGO.API
  alias OmiseGO.API.Crypto
  alias OmiseGO.Eth
  alias OmiseGO.JSONRPC.Client
  alias OmiseGOWatcher.Integration.TestHelper, as: IntegrationTest
  alias OmiseGOWatcher.TestHelper, as: Test
  alias OmiseGO.API.State.Transaction

  @moduletag :integration

  @timeout 20_000
  @zero_address Crypto.zero_address()

  @tag fixtures: [:watcher_sandbox, :contract, :token, :geth, :child_chain, :root_chain_contract_config, :alice, :bob]
  test "challenges invalid exit; exit token", %{contract: contract, token: token, alice: alice, bob: bob} do
    deposit_blknum = IntegrationTest.deposit_to_child_chain(alice, 10, contract)
    # TODO remove slpeep after synch deposit synch
    :timer.sleep(100)
    tx = API.TestHelper.create_encoded([{deposit_blknum, 0, 0, alice}], @zero_address, [{alice, 7}, {bob, 3}])
    {:ok, %{blknum: exiting_utxo_block_nr}} = Client.call(:submit, %{transaction: tx})
    block_nr = exiting_utxo_block_nr

    IntegrationTest.wait_until_block_getter_fetches_block(block_nr, @timeout)

    tx2 = API.TestHelper.create_encoded([{block_nr, 0, 0, alice}], @zero_address, [{alice, 4}, {bob, 3}])
    {:ok, %{blknum: block_nr}} = Client.call(:submit, %{transaction: tx2})

    IntegrationTest.wait_until_block_getter_fetches_block(block_nr, @timeout)

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
        alice_address,
        contract.contract_addr
      )

    {:ok, %{"status" => "0x1"}} = Eth.WaitFor.eth_receipt(txhash, @timeout)

    challenge = get_exit_challenge(exiting_utxo_block_nr, 0, 0)
    assert {:ok, {alice.addr, @zero_address, 7}} == Eth.get_exit(utxo_pos, contract.contract_addr)

    {:ok, txhash} =
      OmiseGO.Eth.DevHelpers.challenge_exit(
        challenge.cutxopos,
        challenge.eutxoindex,
        challenge.txbytes,
        challenge.proof,
        challenge.sigs,
        alice_address,
        contract.contract_addr
      )

    {:ok, %{"status" => "0x1"}} = Eth.WaitFor.eth_receipt(txhash, @timeout)
    assert {:ok, {@zero_address, @zero_address, 7}} == Eth.get_exit(utxo_pos, contract.contract_addr)

    alice_enc = "0x" <> Base.encode16(alice.addr, case: :lower)
    _ = Eth.DevHelpers.token_mint(alice_enc, 20, token.address)

    {:ok, false} = Eth.DevHelpers.has_token(token.address)
    _ = Eth.DevHelpers.add_token(token.address)
    {:ok, true} = Eth.DevHelpers.has_token(token.address)

    Eth.DevHelpers.token_approve(
      alice_enc,
      contract.contract_addr,
      20,
      token.address
    )

    {:ok, receipt} = Eth.DevHelpers.deposit_token(alice_enc, token.address, 20)
    token_deposit_blknum = Eth.DevHelpers.deposit_blknum_from_receipt(receipt)
    # TODO: fix this flakyness! (wait lets CC process the deposit)
    Process.sleep(1000)

    {:ok, currency} = API.Crypto.decode_address(token.address)

    token_raw_tx =
      Transaction.new(
        [{token_deposit_blknum, 0, 0}],
        currency,
        [{alice.addr, 20}]
      )

    token_tx = token_raw_tx |> Transaction.sign(alice.priv, <<>>) |> Transaction.Signed.encode()

    # spend the token deposit
    {:ok, %{blknum: spend_token_child_block}} = Client.call(:submit, %{transaction: token_tx})

    IntegrationTest.wait_until_block_getter_fetches_block(spend_token_child_block, @timeout)
    Process.sleep(100)

    %{
      txbytes: txbytes,
      proof: proof,
      sigs: sigs,
      utxo_pos: utxo_pos
    } = IntegrationTest.compose_utxo_exit(spend_token_child_block, 0, 0)

    {:ok, txhash} =
      Eth.start_exit(
        utxo_pos,
        txbytes,
        proof,
        sigs,
        1,
        alice_address,
        contract.contract_addr
      )

    {:ok, %{"status" => "0x1"}} = Eth.WaitFor.eth_receipt(txhash, @timeout)
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

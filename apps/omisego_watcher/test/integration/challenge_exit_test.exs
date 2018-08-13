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

  @tag fixtures: [:watcher_sandbox, :contract, :geth, :child_chain, :root_chain_contract_config, :alice]
  test "exiting spends UTXO on child chain", %{contract: contract, alice: alice} do
    deposit_blknum = IntegrationTest.deposit_to_child_chain(alice, 10, contract)
    # TODO remove slpeep after synch deposit synch
    :timer.sleep(100)
    tx = API.TestHelper.create_encoded([{deposit_blknum, 0, 0, alice}], @zero_address, [{alice, 10}])
    {:ok, %{blknum: exiting_utxo_block_nr}} = Client.call(:submit, %{transaction: tx})

    IntegrationTest.wait_until_block_getter_fetches_block(exiting_utxo_block_nr, @timeout)

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

    # wait until the exit is recognized and attempt to spend the exited utxo
    Process.sleep(1_000)
    tx2 = API.TestHelper.create_encoded([{exiting_utxo_block_nr, 0, 0, alice}], @zero_address, [{alice, 10}])
    {:error, {-32603, "Internal error", "utxo_not_found"}} = Client.call(:submit, %{transaction: tx2})
  end

  @tag fixtures: [:watcher_sandbox, :contract, :geth, :child_chain, :root_chain_contract_config, :alice]
  test "exit eth, with challenging an invalid exit", %{contract: contract, alice: alice} do
    deposit_blknum = IntegrationTest.deposit_to_child_chain(alice, 10, contract)
    # TODO remove slpeep after synch deposit synch
    :timer.sleep(100)
    tx = API.TestHelper.create_encoded([{deposit_blknum, 0, 0, alice}], @zero_address, [{alice, 10}])
    {:ok, %{blknum: exiting_utxo_block_nr}} = Client.call(:submit, %{transaction: tx})

    IntegrationTest.wait_until_block_getter_fetches_block(exiting_utxo_block_nr, @timeout)

    tx2 = API.TestHelper.create_encoded([{exiting_utxo_block_nr, 0, 0, alice}], @zero_address, [{alice, 10}])
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
        alice_address,
        contract.contract_addr
      )

    {:ok, %{"status" => "0x1"}} = Eth.WaitFor.eth_receipt(txhash, @timeout)

    # after a successful invalid exit starting, the Watcher should be able to assist in successful challenging
    challenge = get_exit_challenge(exiting_utxo_block_nr, 0, 0)
    assert {:ok, {alice.addr, @zero_address, 10}} == Eth.get_exit(utxo_pos, contract.contract_addr)

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
    assert {:ok, {@zero_address, @zero_address, 10}} == Eth.get_exit(utxo_pos, contract.contract_addr)
  end

  @tag fixtures: [:watcher_sandbox, :contract, :token, :geth, :child_chain, :root_chain_contract_config, :alice]
  test "exit erc20, without challenging an invalid exit", %{contract: contract, token: token, alice: alice} do
    # NOTE: we're explicitly skipping the challenge here, because eth and erc20 exits/challenges work the exact same
    #       way, so the integration is tested with the eth test already

    {:ok, alice_address} = Eth.DevHelpers.import_unlock_fund(alice)

    _ = Eth.DevHelpers.token_mint(alice_address, 10, token.address)

    {:ok, false} = Eth.DevHelpers.has_token(token.address)
    _ = Eth.DevHelpers.add_token(token.address)
    {:ok, true} = Eth.DevHelpers.has_token(token.address)

    Eth.DevHelpers.token_approve(
      alice_address,
      contract.contract_addr,
      10,
      token.address
    )

    {:ok, receipt} = Eth.DevHelpers.deposit_token(alice_address, token.address, 10)
    token_deposit_blknum = Eth.DevHelpers.deposit_blknum_from_receipt(receipt)
    # TODO: fix this flakyness! (wait lets CC process the deposit)
    Process.sleep(1000)

    {:ok, currency} = API.Crypto.decode_address(token.address)

    token_raw_tx =
      Transaction.new(
        [{token_deposit_blknum, 0, 0}],
        currency,
        [{alice.addr, 10}]
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

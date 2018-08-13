defmodule OmiseGO.API.Integration.HappyPathTest do
  @moduledoc """
  Tests a simple happy path of all the pieces working together
  """

  use ExUnitFixtures
  use ExUnit.Case, async: false
  use OmiseGO.Eth.Fixtures
  use OmiseGO.DB.Fixtures

  alias OmiseGO.API.BlockQueue
  alias OmiseGO.API.Crypto
  alias OmiseGO.API.State.Transaction
  alias OmiseGO.Eth
  alias OmiseGO.JSONRPC.Client

  import OmiseGO.Eth.Integration.DepositHelper

  @moduletag :integration

  deffixture omisego(root_chain_contract_config, token_contract_config, db_initialized) do
    # match variables to hide "unused var" warnings (can't be fixed by underscoring in line above, breaks macro):
    _ = root_chain_contract_config
    _ = db_initialized
    _ = token_contract_config
    Application.put_env(:omisego_api, :ethereum_event_block_finality_margin, 2, persistent: true)
    # need to overide that to very often, so that many checks fall in between a single child chain block submission
    Application.put_env(:omisego_api, :ethereum_event_get_deposits_interval_ms, 10, persistent: true)
    {:ok, started_apps} = Application.ensure_all_started(:omisego_api)
    {:ok, started_jsonrpc} = Application.ensure_all_started(:omisego_jsonrpc)

    on_exit(fn ->
      (started_apps ++ started_jsonrpc)
      |> Enum.reverse()
      |> Enum.map(fn app -> :ok = Application.stop(app) end)
    end)

    :ok
  end

  defp eth, do: Crypto.zero_address()

  @tag fixtures: [:alice, :bob, :omisego, :token]
  test "deposit, spend, exit, restart etc works fine", %{alice: alice, bob: bob, token: token} do
    {:ok, alice_enc} = Eth.DevHelpers.import_unlock_fund(alice)

    # get some test eth and tokens for Alice
    deposit_blknum = deposit_to_child_chain(alice_enc, 10)
    token_deposit_blknum = deposit_to_child_chain(alice_enc, 20, token)

    raw_tx = Transaction.new([{deposit_blknum, 0, 0}], eth(), [{bob.addr, 7}, {alice.addr, 3}])

    tx = raw_tx |> Transaction.sign(alice.priv, <<>>) |> Transaction.Signed.encode()

    # spend the deposit
    {:ok, %{blknum: spend_child_block}} = Client.call(:submit, %{transaction: tx})

    {:ok, token_addr} = OmiseGO.API.Crypto.decode_address(token.address)

    token_raw_tx =
      Transaction.new(
        [{token_deposit_blknum, 0, 0}],
        token_addr,
        [{bob.addr, 18}, {alice.addr, 2}]
      )

    token_tx = token_raw_tx |> Transaction.sign(alice.priv, <<>>) |> Transaction.Signed.encode()

    # spend the token deposit
    {:ok, %{blknum: _spend_token_child_block}} = Client.call(:submit, %{transaction: token_tx})

    post_spend_child_block = spend_child_block + BlockQueue.child_block_interval()
    {:ok, _} = Eth.DevHelpers.wait_for_current_child_block(post_spend_child_block, true)

    # check if operator is propagating block with hash submitted to RootChain
    {:ok, {block_hash, _}} = Eth.get_child_chain(spend_child_block)
    {:ok, %{transactions: transactions}} = Client.call(:get_block, %{hash: block_hash})
    eth_tx = hd(transactions)
    {:ok, %{raw_tx: raw_tx_decoded}} = Transaction.Signed.decode(eth_tx)
    assert raw_tx_decoded == raw_tx

    # Restart everything to check persistance and revival
    [:omisego_api, :omisego_eth, :omisego_db] |> Enum.each(&Application.stop/1)

    {:ok, started_apps} = Application.ensure_all_started(:omisego_api)
    # sanity check, did-we restart really?
    assert Enum.member?(started_apps, :omisego_api)

    # repeat spending to see if all works

    raw_tx2 = Transaction.new([{spend_child_block, 0, 0}, {spend_child_block, 0, 1}], eth(), [{alice.addr, 10}])
    tx2 = raw_tx2 |> Transaction.sign(bob.priv, alice.priv) |> Transaction.Signed.encode()

    # spend the output of the first eth_tx
    {:ok, %{blknum: spend_child_block2}} = Client.call(:submit, %{transaction: tx2})

    post_spend_child_block2 = spend_child_block2 + BlockQueue.child_block_interval()
    {:ok, _} = Eth.DevHelpers.wait_for_current_child_block(post_spend_child_block2, true)

    # check if operator is propagating block with hash submitted to RootChain
    {:ok, {block_hash2, _}} = Eth.get_child_chain(spend_child_block2)

    {:ok, %{transactions: [transaction2]}} = Client.call(:get_block, %{hash: block_hash2})
    {:ok, %{raw_tx: raw_tx_decoded2}} = Transaction.Signed.decode(transaction2)
    assert raw_tx2 == raw_tx_decoded2

    # sanity checks
    assert {:ok, %{}} = Client.call(:get_block, %{hash: block_hash})
    assert {:error, {_, "Internal error", "not_found"}} = Client.call(:get_block, %{hash: <<0::size(256)>>})

    assert {:error, {_, "Internal error", "utxo_not_found"}} = Client.call(:submit, %{transaction: tx})

    assert {:error, {_, "Internal error", "utxo_not_found"}} = Client.call(:submit, %{transaction: tx2})

    assert {:error, {_, "Internal error", "utxo_not_found"}} = Client.call(:submit, %{transaction: token_tx})
  end
end

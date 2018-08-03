defmodule OmiseGO.API.Integration.HappyPathTest do
  @moduledoc """
  Tests a simple happy path of all the pieces working together
  """

  use ExUnitFixtures
  use ExUnit.Case, async: false
  use OmiseGO.Eth.Fixtures
  use OmiseGO.DB.Fixtures

  alias OmiseGO.API.BlockQueue
  alias OmiseGO.API.State.Transaction
  alias OmiseGO.Eth
  alias OmiseGO.JSONRPC.Client

  @moduletag :integration

  deffixture omisego(root_chain_contract_config, db_initialized) do
    :ok = root_chain_contract_config
    :ok = db_initialized
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

  defp eth, do: OmiseGO.API.Crypto.zero_address()

  @tag fixtures: [:alice, :bob, :omisego]
  test "deposit, spend, exit, restart etc works fine", %{alice: alice, bob: bob} do
    {:ok, alice_enc} = Eth.DevHelpers.import_unlock_fund(alice)

    {:ok, deposit_tx_hash} = Eth.DevHelpers.deposit(10, 0, alice_enc)
    {:ok, receipt} = Eth.WaitFor.eth_receipt(deposit_tx_hash)

    deposit_blknum = Eth.DevHelpers.deposit_blknum_from_receipt(receipt)

    # wait until the deposit is recognized by child chain
    post_deposit_child_block =
      deposit_blknum - 1 +
        (Application.get_env(:omisego_api, :ethereum_event_block_finality_margin) + 1) *
          BlockQueue.child_block_interval()

    # TODO: possible source of flakiness is that State did not process deposit on time
    Process.sleep(500)

    {:ok, _} = Eth.DevHelpers.wait_for_current_child_block(post_deposit_child_block, true)

    raw_tx = Transaction.new([{deposit_blknum, 0, 0}], eth(), [{bob.addr, 7}, {alice.addr, 3}])

    tx = raw_tx |> Transaction.sign(alice.priv, <<>>) |> Transaction.Signed.encode()

    # spend the deposit
    {:ok, %{blknum: spend_child_block}} = Client.call(:submit, %{transaction: tx})

    post_spend_child_block = spend_child_block + BlockQueue.child_block_interval()
    {:ok, _} = Eth.DevHelpers.wait_for_current_child_block(post_spend_child_block, true)

    # check if operator is propagating block with hash submitted to RootChain
    {:ok, {block_hash, _}} = Eth.get_child_chain(spend_child_block)
    {:ok, %{transactions: [transaction]}} = Client.call(:get_block, %{hash: block_hash})
    {:ok, %{raw_tx: raw_tx_decoded}} = Transaction.Signed.decode(transaction)
    assert raw_tx_decoded == raw_tx

    # Restart everything to check persistance and revival
    [:omisego_api, :omisego_eth, :omisego_db] |> Enum.each(&Application.stop/1)

    # TODO: possible source of flakiness is omisego_db not cleaning up fast enough? find a better solution
    Process.sleep(500)

    {:ok, started_apps} = Application.ensure_all_started(:omisego_api)
    # sanity check, did-we restart really?
    assert Enum.member?(started_apps, :omisego_api)

    # repeat spending to see if all works

    raw_tx2 = Transaction.new([{spend_child_block, 0, 0}, {spend_child_block, 0, 1}], eth(), [{alice.addr, 10}])
    tx2 = raw_tx2 |> Transaction.sign(bob.priv, alice.priv) |> Transaction.Signed.encode()

    # spend the output of the first transaction
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
  end
end

defmodule OmiseGO.API.Integration.HappyPathTest do
  @moduledoc """
  Tests a simple happy path of all the pieces working together
  """

  use ExUnitFixtures
  use ExUnit.Case, async: false

  alias OmiseGO.DB
  alias OmiseGO.Eth
  alias OmiseGO.API.State.Transaction
  alias OmiseGO.API.TestHelper
  alias OmiseGO.API.BlockQueue

  @moduletag :integration

  deffixture db_path_config() do
    dir = Temp.mkdir!()

    Application.put_env(:omisego_db, :leveldb_path, dir, persistent: true)
    {:ok, started_apps} = Application.ensure_all_started(:omisego_db)

    on_exit fn ->
      Application.put_env(:omisego_db, :leveldb_path, nil)
      started_apps
        |> Enum.reverse()
        |> Enum.map(fn app -> :ok = Application.stop(app) end)
    end
    :ok
  end

  # TODO: geth and contract fixtures copied from eth/fixtures - DRY
  # possible solution 1: remove eth_test and cover behaviors here
  # possible solution 2: move current eth smoke test to integration level tests of omisego_api and move fixtures too
  deffixture geth do
    {:ok, exit_fn} = OmiseGO.Eth.dev_geth()
    on_exit(exit_fn)
    :ok
  end
  deffixture contract(geth) do
    _ = geth
    _ = Application.ensure_all_started(:ethereumex)
    {:ok, contract_address, txhash, authority} = OmiseGO.Eth.DevHelpers.prepare_env("../../")

    %{
      address: contract_address,
      from: authority,
      txhash: txhash
    }
  end

  deffixture root_chain_contract_config(geth, contract) do
    # prevent warnings
    :ok = geth

    Application.put_env(:omisego_eth, :contract, contract.address, persistent: true)
    Application.put_env(:omisego_eth, :authority_addr, contract.from, persistent: true)
    Application.put_env(:omisego_eth, :txhash_contract, contract.txhash, persistent: true)

    {:ok, started_apps} = Application.ensure_all_started(:omisego_eth)

    on_exit fn ->
      Application.put_env(:omisego_eth, :contract, "0x0")
      Application.put_env(:omisego_eth, :authority_addr, "0x0")
      Application.put_env(:omisego_eth, :txhash_contract, "0x0")
      started_apps
        |> Enum.reverse()
        |> Enum.map(fn app -> :ok = Application.stop(app) end)
    end
    :ok
  end

  deffixture db_initialized(db_path_config) do
    :ok = db_path_config
    :ok = OmiseGO.DB.multi_update([{:put, :last_deposit_block_height, 0}])
    :ok = OmiseGO.DB.multi_update([{:put, :child_top_block_number, 0}])
    :ok
  end

  deffixture omisego(root_chain_contract_config, db_initialized) do
    :ok = root_chain_contract_config
    :ok = db_initialized
    Application.put_env(:omisego_api, :ethereum_event_block_finality_margin, 2, persistent: true)
    Application.put_env(:omisego_api, :ethereum_event_get_deposits_interval_ms, 1000, persistent: true)
    {:ok, started_apps} = Application.ensure_all_started(:omisego_api)

    on_exit fn ->
      started_apps
        |> Enum.reverse()
        |> Enum.map(fn app -> :ok = Application.stop(app) end)
    end
    :ok
  end

  @tag fixtures: [:alice, :bob, :omisego]
  @tag :happy
  test "deposit, spend, exit, restart etc works fine", %{alice: alice, bob: bob} do

    {:ok, alice_enc} = TestHelper.import_unlock_fund(alice)

    {:ok, pre_deposit_child_block} = Eth.get_current_child_block()

    {:ok, deposit_tx_hash} = Eth.DevHelpers.deposit(10, 0, alice_enc)
    {:ok, _} = Eth.WaitFor.eth_receipt(deposit_tx_hash)

    # mine the block that spends the deposit
    post_deposit_child_block =
      pre_deposit_child_block +
      Application.get_env(:omisego_api, :ethereum_event_block_finality_margin) * BlockQueue.child_block_interval()
    {:ok, _} = OmiseGO.Eth.DevHelpers.wait_for_current_child_block(post_deposit_child_block, true)

    # TODO: hacky way to get the deposit height, fix sometime
    {:ok, [utxos]} = DB.utxos()
    [{deposit_block, _, _}] = Map.keys(utxos)

    raw_tx = Transaction.new([{deposit_block, 0, 0}], [{bob.addr, 7}, {alice.addr, 3}], 0)
    tx =
      raw_tx
      |> Transaction.sign(alice.priv, <<>>)
      |> Transaction.Signed.encode()

    # spend the deposit
    {:ok, _, spend_child_block, _} = OmiseGO.API.submit(tx)

    post_spend_child_block = spend_child_block + OmiseGO.API.BlockQueue.child_block_interval()
    {:ok, _} = OmiseGO.Eth.DevHelpers.wait_for_current_child_block(post_spend_child_block, true)

    # check if operator is propagating block with hash submitted to RootChain
    {:ok, {block_hash, _}} = OmiseGO.Eth.get_child_chain(spend_child_block)
    assert %OmiseGO.API.Block{
      transactions: [
        %Transaction.Recovered{
          raw_tx: ^raw_tx
        }
      ]
    } = OmiseGO.API.get_block(block_hash)

    # Restart everything to check persistance and revival
    [:omisego_api, :omisego_eth, :omisego_db]
    |> Enum.each(&Application.stop/1)

    {:ok, started_apps} = Application.ensure_all_started(:omisego_api)
    # sanity check, did-we restart really?
    assert Enum.member?(started_apps, :omisego_api)

    # repeat spending to see if all works

    raw_tx2 = Transaction.new(
      [{spend_child_block, 0, 0}, {spend_child_block, 0, 1}],
      [{alice.addr, 10}],
      0
    )
    tx2 =
      raw_tx2
      |> Transaction.sign(bob.priv, alice.priv)
      |> Transaction.Signed.encode()

    # spend the deposit
    {:ok, _, spend_child_block2, _} = OmiseGO.API.submit(tx2)

    post_spend_child_block2 = spend_child_block2 + BlockQueue.child_block_interval()
    {:ok, _} = OmiseGO.Eth.DevHelpers.wait_for_current_child_block(post_spend_child_block2, true)

    # check if operator is propagating block with hash submitted to RootChain
    {:ok, {block_hash2, _}} = OmiseGO.Eth.get_child_chain(spend_child_block2)
    assert %OmiseGO.API.Block{
      transactions: [
        %Transaction.Recovered{
          raw_tx: ^raw_tx2
        }
      ]
    } = OmiseGO.API.get_block(block_hash2)

    # sanity checks
    assert %OmiseGO.API.Block{} = OmiseGO.API.get_block(block_hash)
    assert :not_found = OmiseGO.API.get_block(<<0::size(256)>>)
    assert {:error, :utxo_not_found} = OmiseGO.API.submit(tx)
  end

end

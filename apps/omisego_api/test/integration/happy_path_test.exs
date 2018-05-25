defmodule OmiseGO.API.Integration.HappyPathTest do
  @moduledoc """
  Tests a simple happy path of all the pieces working together
  """

  use ExUnitFixtures
  use ExUnit.Case, async: false
  use Omisego.Eth.GethFixtures

  alias OmiseGO.Eth
  alias OmiseGO.API.State.Transaction
  alias OmiseGO.API.BlockQueue

  @moduletag :integration

  deffixture db_path_config() do
    {:ok, briefly} = Application.ensure_all_started(:briefly)
    {:ok, dir} = Briefly.create(directory: true)

    Application.put_env(:omisego_db, :leveldb_path, dir, persistent: true)
    {:ok, started_apps} = Application.ensure_all_started(:omisego_db)

    on_exit(fn ->
      Application.put_env(:omisego_db, :leveldb_path, nil)

      (briefly ++ started_apps)
      |> Enum.reverse()
      |> Enum.map(fn app -> :ok = Application.stop(app) end)
    end)

    :ok
  end

  deffixture root_chain_contract_config(geth, contract) do
    # prevent warnings
    :ok = geth

    Application.put_env(:omisego_eth, :contract, contract.address, persistent: true)
    Application.put_env(:omisego_eth, :authority_addr, contract.from, persistent: true)
    Application.put_env(:omisego_eth, :txhash_contract, contract.txhash, persistent: true)

    {:ok, started_apps} = Application.ensure_all_started(:omisego_eth)

    on_exit(fn ->
      Application.put_env(:omisego_eth, :contract, "0x0")
      Application.put_env(:omisego_eth, :authority_addr, "0x0")
      Application.put_env(:omisego_eth, :txhash_contract, "0x0")

      started_apps
      |> Enum.reverse()
      |> Enum.map(fn app -> :ok = Application.stop(app) end)
    end)

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

  def jsonrpc(method, params) do
    jsonrpc_port = Application.get_env(:omisego_jsonrpc, :omisego_api_rpc_port)

    "http://localhost:#{jsonrpc_port}"
    |> JSONRPC2.Clients.HTTP.call(to_string(method), params)
  end

  @tag fixtures: [:alice, :bob, :omisego]
  test "deposit, spend, exit, restart etc works fine", %{alice: alice, bob: bob} do
    {:ok, alice_enc} = Eth.DevHelpers.import_unlock_fund(alice)

    {:ok, deposit_tx_hash} = Eth.DevHelpers.deposit(10, 0, alice_enc)
    {:ok, receipt} = Eth.WaitFor.eth_receipt(deposit_tx_hash)

    deposit_height = Eth.DevHelpers.deposit_height_from_receipt(receipt)

    # wait until the deposit is recognized by child chain
    post_deposit_child_block =
      deposit_height - 1 +
        (Application.get_env(:omisego_api, :ethereum_event_block_finality_margin) + 1) *
          BlockQueue.child_block_interval()

    {:ok, _} = Eth.DevHelpers.wait_for_current_child_block(post_deposit_child_block, true)

    raw_tx = Transaction.new([{deposit_height, 0, 0}], [{bob.addr, 7}, {alice.addr, 3}], 0)

    tx = raw_tx |> Transaction.sign(alice.priv, <<>>) |> Transaction.Signed.encode()

    # spend the deposit
    {:ok, %{"blknum" => spend_child_block}} = jsonrpc(:submit, %{transaction: Base.encode16(tx)})

    post_spend_child_block = spend_child_block + BlockQueue.child_block_interval()
    {:ok, _} = Eth.DevHelpers.wait_for_current_child_block(post_spend_child_block, true)

    # check if operator is propagating block with hash submitted to RootChain
    {:ok, {block_hash, _}} = Eth.get_child_chain(spend_child_block)
    encoded_raw_tx = encode(raw_tx)

    assert {:ok, %{"transactions" => [%{"raw_tx" => ^encoded_raw_tx}]}} =
             jsonrpc(:get_block, %{hash: Base.encode16(block_hash)})

    # Restart everything to check persistance and revival
    [:omisego_api, :omisego_eth, :omisego_db] |> Enum.each(&Application.stop/1)

    {:ok, started_apps} = Application.ensure_all_started(:omisego_api)
    # sanity check, did-we restart really?
    assert Enum.member?(started_apps, :omisego_api)

    # repeat spending to see if all works

    raw_tx2 = Transaction.new([{spend_child_block, 0, 0}, {spend_child_block, 0, 1}], [{alice.addr, 10}], 0)
    encoded_raw_tx2 = encode(raw_tx2)
    tx2 = raw_tx2 |> Transaction.sign(bob.priv, alice.priv) |> Transaction.Signed.encode()

    # spend the output of the first transaction
    {:ok, %{"blknum" => spend_child_block2}} = jsonrpc(:submit, %{transaction: Base.encode16(tx2)})

    post_spend_child_block2 = spend_child_block2 + BlockQueue.child_block_interval()
    {:ok, _} = Eth.DevHelpers.wait_for_current_child_block(post_spend_child_block2, true)

    # check if operator is propagating block with hash submitted to RootChain
    {:ok, {block_hash2, _}} = Eth.get_child_chain(spend_child_block2)

    assert {:ok, %{"transactions" => [%{"raw_tx" => ^encoded_raw_tx2}]}} =
             jsonrpc(:get_block, %{hash: Base.encode16(block_hash2)})

    # sanity checks
    assert {:ok, %{}} = jsonrpc(:get_block, %{hash: Base.encode16(block_hash)})
    assert {:ok, "not_found"} = jsonrpc(:get_block, %{hash: Base.encode16(<<0::size(256)>>)})

    assert {:error, {_, "Internal error", "utxo_not_found"}} = jsonrpc(:submit, %{transaction: Base.encode16(tx)})

    assert {:error, {_, "Internal error", "utxo_not_found"}} = jsonrpc(:submit, %{transaction: Base.encode16(tx2)})
  end

  defp encode(arg) when is_binary(arg), do: Base.encode16(arg)

  defp encode(arg) when is_map(arg) do
    arg = Map.from_struct(arg)

    for {key, value} <- arg, into: %{} do
      {to_string(key), encode(value)}
    end
  end

  defp encode(arg) when is_list(arg), do: for(value <- arg, into: [], do: encode(value))
  defp encode(arg), do: arg
end

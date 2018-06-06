defmodule OmiseGOWatcher.BlockGetterTest do
  use ExUnitFixtures
  use ExUnit.Case, async: false

  use Plug.Test

  alias OmiseGO.Eth
  alias OmiseGO.API.State.Transaction
  alias OmiseGO.JSONRPC.Client

  @moduletag :integration

  defp deposit_to_child_chain(to, value, config) do
    {:ok, destiny_enc} = Eth.DevHelpers.import_unlock_fund(to)
    {:ok, deposit_tx_hash} = Eth.DevHelpers.deposit(value, 0, destiny_enc, config.contract.address)
    {:ok, receipt} = Eth.WaitFor.eth_receipt(deposit_tx_hash)
    deposit_height = Eth.DevHelpers.deposit_height_from_receipt(receipt)

    post_deposit_child_block =
      deposit_height - 1 + (config.ethereum_event_block_finality_margin + 1) * config.child_block_interval
    {:ok, _} =
      Eth.DevHelpers.wait_for_current_child_block(post_deposit_child_block, true, 60_000, config.contract.address)
    deposit_height
  end

  @tag fixtures: [:watcher_sandbox, :config_map, :geth, :child_chain, :alice, :bob]
  test "get the blocks from child chain after transaction", %{config_map: config_map, alice: alice, bob: bob} do
    Application.put_env(:omisego_eth, :contract_address, config_map.contract.address)

    {:ok, _pid} =
      GenServer.start_link(
        OmiseGOWatcher.BlockGetter,
        %{contract_address: config_map.contract.address},
        name: BlockGetter
      )

    deposit_height = deposit_to_child_chain(alice, 10, config_map)
    raw_tx = Transaction.new([{deposit_height, 0, 0}], [{alice.addr, 7}, {bob.addr, 3}], 0)
    tx = raw_tx |> Transaction.sign(alice.priv, <<>>) |> Transaction.Signed.encode()

    {:ok, %{"blknum" => block_nr}} = Client.call(:submit, %{transaction: tx})

    # wait for BlockGetter get the block
    fn ->
      Eth.WaitFor.repeat_until_ok(fn ->
        # TODO use event system
        case GenServer.call(BlockGetter, :get_height) < block_nr do
          true -> :repeat
          false -> {:ok, block_nr}
        end
      end)
    end
    |> Task.async()
    |> Task.await(10_000)

    encode_tx = Client.encode(tx)

    assert [%{"amount" => 3, "blknum" => block_nr, "oindex" => 0, "txindex" => 0, "txbytes" => encode_tx}] ==
             get_utxo(bob)

    assert [%{"amount" => 7, "blknum" => block_nr, "oindex" => 0, "txindex" => 0, "txbytes" => encode_tx}] ==
             get_utxo(alice)
  end

  defp get_utxo(from) do
    response =
      :get
      |> conn("account/utxo?address=#{Client.encode(from.addr)}")
      |> put_private(:plug_skip_csrf_protection, true)
      |> OmiseGOWatcherWeb.Endpoint.call([])

    Poison.decode!(response.resp_body)["utxos"]
  end
end

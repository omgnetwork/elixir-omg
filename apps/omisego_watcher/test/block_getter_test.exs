defmodule OmiseGOWatcher.BlockGetterTest do
  use ExUnitFixtures
  use ExUnit.Case, async: false
  use OmiseGO.API.Fixtures
  use Plug.Test

  alias OmiseGO.API.Block
  alias OmiseGO.API.TestHelper, as: API_Helper
  alias OmiseGO.API.State.Transaction
  alias OmiseGO.Eth
  alias OmiseGO.JSONRPC.Client

  @moduletag :integration

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
  test "get the blocks from child chain", %{config_map: config_map, alice: alice, bob: bob} do
    {:ok, _pid} =
      GenServer.start_link(
        OmiseGOWatcher.BlockGetter,
        %{contract_address: config_map.contract_addr},
        name: BlockGetter
      )

    deposit_blknum = deposit_to_child_chain(alice, 10, config_map)
    raw_tx = Transaction.new([{deposit_blknum, 0, 0}], Transaction.zero_address(), [{alice.addr, 7}, {bob.addr, 3}])
    tx = raw_tx |> Transaction.sign(alice.priv, <<>>) |> Transaction.Signed.encode()

    {:ok, %{"blknum" => block_nr}} = Client.call(:submit, %{transaction: tx})

    # wait for BlockGetter get the block
    fn ->
      Eth.WaitFor.repeat_until_ok(fn ->
        # TODO use event system
        case GenServer.call(BlockGetter, :get_height, 10_000) < block_nr do
          true -> :repeat
          false -> {:ok, block_nr}
        end
      end)
    end
    |> Task.async()
    |> Task.await(60_000)

    encode_tx = Client.encode(tx)

    assert [%{"amount" => 3, "blknum" => block_nr, "oindex" => 0, "txindex" => 0, "txbytes" => encode_tx}] ==
             get_utxo(bob)

    assert [%{"amount" => 7, "blknum" => block_nr, "oindex" => 0, "txindex" => 0, "txbytes" => encode_tx}] ==
             get_utxo(alice)
  end

  @tag fixtures: [:watcher_sandbox, :alice]
  test "try consume block with invalid transaction", %{alice: alice} do
    assert {:error, :amounts_dont_add_up} ==
             OmiseGOWatcher.BlockGetter.consume_block(%Block{
               transactions: [API_Helper.create_recovered([], [{alice, 1200}], 0)],
               number: 1_000
             })

    assert {:error, :utxo_not_found} ==
             OmiseGOWatcher.BlockGetter.consume_block(%Block{
               transactions: [API_Helper.create_recovered([{1_000, 0, 0, alice}], [{alice, 1200}], 0)],
               number: 1_000
             })
  end

  @tag fixtures: [:watcher_sandbox, :alice, :carol, :bob]
  test "consume block with valid transactions", %{alice: alice, carol: carol, bob: bob} do
    OmiseGOWatcher.BlockGetter.consume_block(%Block{
      transactions: [],
      number: 1_000
    })

    assert :ok ==
             OmiseGO.API.State.deposit([
               %{owner: "0x" <> Base.encode16(alice.addr, case: :lower), amount: 1_000, blknum: 1_001},
               %{owner: "0x" <> Base.encode16(bob.addr, case: :lower), amount: 1_000, blknum: 1_002}
             ])

    assert :ok ==
             OmiseGOWatcher.BlockGetter.consume_block(%Block{
               transactions: [
                 API_Helper.create_recovered([{1_001, 0, 0, alice}], [{alice, 700}, {carol, 200}], 100),
                 API_Helper.create_recovered([{1_002, 0, 0, bob}], [{carol, 500}, {bob, 400}], 100)
               ],
               number: 2_000
             })

    assert [%{"amount" => 700, "blknum" => 2000, "oindex" => 0, "txindex" => 0}] = get_utxo(alice)
    assert [%{"amount" => 400, "blknum" => 2000, "oindex" => 0, "txindex" => 1}] = get_utxo(bob)

    assert [
             %{"amount" => 200, "blknum" => 2000, "oindex" => 0, "txindex" => 0},
             %{"amount" => 500, "blknum" => 2000, "oindex" => 0, "txindex" => 1}
           ] = get_utxo(carol)
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

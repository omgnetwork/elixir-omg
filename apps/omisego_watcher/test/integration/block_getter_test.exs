defmodule OmiseGOWatcher.BlockGetterTest do
  use ExUnitFixtures
  use ExUnit.Case, async: false
  use OmiseGO.API.Fixtures
  use Plug.Test
  use Phoenix.ChannelTest

  alias OmiseGO.API
  alias OmiseGO.API.Crypto
  alias OmiseGO.API.Utxo
  require Utxo
  alias OmiseGO.Eth
  alias OmiseGO.JSONRPC.Client
  alias OmiseGOWatcher.Eventer.Event
  alias OmiseGOWatcher.Integration
  alias OmiseGOWatcher.TestHelper
  alias OmiseGOWatcherWeb.ByzantineChannel
  alias OmiseGOWatcherWeb.TransferChannel

  import ExUnit.CaptureLog

  @moduletag :integration

  @timeout 20_000
  @eth Crypto.zero_address()
  @eth_hex String.duplicate("00", 20)

  @endpoint OmiseGOWatcherWeb.Endpoint

  @tag fixtures: [:watcher_sandbox, :contract, :geth, :child_chain, :root_chain_contract_config, :alice, :bob]
  test "get the blocks from child chain after transaction and start exit",
       %{contract: contract, alice: alice, bob: bob} do
    {:ok, alice_address} = Crypto.encode_address(alice.addr)

    {:ok, _, _socket} =
      subscribe_and_join(socket(), TransferChannel, TestHelper.create_topic("transfer", alice_address))

    deposit_blknum = Integration.TestHelper.deposit_to_child_chain(alice, 10, contract)
    # TODO remove slpeep after synch deposit synch
    :timer.sleep(100)
    tx = API.TestHelper.create_encoded([{deposit_blknum, 0, 0, alice}], @eth, [{alice, 7}, {bob, 3}])
    {:ok, %{blknum: block_nr}} = Client.call(:submit, %{transaction: tx})

    Integration.TestHelper.wait_until_block_getter_fetches_block(block_nr, @timeout)

    encode_tx = Client.encode(tx)

    # TODO write to db seems to be async and wait_until_block_getter_fetches_block
    # returns too early

    :timer.sleep(100)

    assert [
             %{
               "currency" => @eth_hex,
               "amount" => 3,
               "blknum" => block_nr,
               "oindex" => 0,
               "txindex" => 0,
               "txbytes" => encode_tx
             }
           ] == get_utxo(bob)

    assert [
             %{
               "currency" => @eth_hex,
               "amount" => 7,
               "blknum" => block_nr,
               "oindex" => 0,
               "txindex" => 0,
               "txbytes" => encode_tx
             }
           ] == get_utxo(alice)

    {:ok, recovered_tx} = API.Core.recover_tx(tx)
    {:ok, {block_hash, _}} = Eth.get_child_chain(block_nr)

    # TODO: this is turned off now and set to zero. Rethink test after this gets fixed (possibly test differently)
    eth_height = 0

    address_received_event =
      Client.encode(%Event.AddressReceived{
        tx: recovered_tx,
        child_blknum: block_nr,
        child_block_hash: block_hash,
        submited_at_ethheight: eth_height
      })

    address_spent_event =
      Client.encode(%Event.AddressSpent{
        tx: recovered_tx,
        child_blknum: block_nr,
        child_block_hash: block_hash,
        submited_at_ethheight: eth_height
      })

    assert_push("address_received", ^address_received_event)

    assert_push("address_spent", ^address_spent_event)

    %{
      utxo_pos: utxo_pos,
      txbytes: txbytes,
      proof: proof,
      sigs: sigs
    } = Integration.TestHelper.compose_utxo_exit(block_nr, 0, 0)

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

    {:ok, height} = Eth.get_ethereum_height()

    utxo_pos = Utxo.position(block_nr, 0, 0) |> Utxo.Position.encode()

    assert {:ok, [%{amount: 7, utxo_pos: utxo_pos, owner: alice_address, token: @eth}]} ==
             Eth.get_exits(0, height, contract.contract_addr)
  end

  @tag fixtures: [:watcher_sandbox, :geth, :contract, :alice]
  test "diffrent hash send by child chain", %{alice: alice, contract: contract} do
    defmodule BadChildChainHash do
      use JSONRPC2.Server.Handler

      def empty_block, do: [] |> API.Block.hashed_txs_at(1000)
      def different_hash, do: <<0::256>>

      def handle_request(_, _) do
        Client.encode(%API.Block{empty_block() | hash: different_hash()})
      end
    end

    {:ok, _, _socket} = subscribe_and_join(socket(), ByzantineChannel, "byzantine")

    JSONRPC2.Servers.HTTP.http(BadChildChainHash, port: Application.get_env(:omisego_jsonrpc, :omisego_api_rpc_port))

    assert capture_log(fn ->
             {:ok, _txhash} =
               Eth.submit_block(
                 %Eth.BlockSubmission{
                   num: 1000,
                   hash: BadChildChainHash.different_hash(),
                   nonce: 1,
                   gas_price: 20_000_000_000
                 },
                 contract.authority_addr,
                 contract.contract_addr
               )

             assert_block_getter_down()
           end) =~ inspect(:incorrect_hash)

    invalid_block_event =
      Client.encode(%Event.InvalidBlock{
        error_type: :incorrect_hash,
        hash: BadChildChainHash.different_hash(),
        number: 1000
      })

    assert_push("invalid_block", ^invalid_block_event)

    JSONRPC2.Servers.HTTP.shutdown(BadChildChainHash)
  end

  @tag fixtures: [:watcher_sandbox, :contract, :geth]
  test "bad transaction with not existing utxo, detected by interactions with State", %{contract: contract} do
    defmodule BadChildChainTransaction do
      use JSONRPC2.Server.Handler

      # using module attribute to have a stable alice (we can't use fixtures, because modules don't see the parent
      @alice API.TestHelper.generate_entity()

      def block_with_incorrect_transaction do
        alice = @alice

        recovered = API.TestHelper.create_recovered([{1, 0, 0, alice}], Crypto.zero_address(), [{alice, 10}])

        API.Block.hashed_txs_at([recovered], 1000)
      end

      def handle_request(_, _) do
        Client.encode(block_with_incorrect_transaction())
      end
    end

    {:ok, _, _socket} = subscribe_and_join(socket(), ByzantineChannel, "byzantine")

    JSONRPC2.Servers.HTTP.http(
      BadChildChainTransaction,
      port: Application.get_env(:omisego_jsonrpc, :omisego_api_rpc_port)
    )

    %API.Block{hash: hash} = BadChildChainTransaction.block_with_incorrect_transaction()

    assert capture_log(fn ->
             {:ok, _txhash} =
               Eth.submit_block(
                 %Eth.BlockSubmission{
                   num: 1_000,
                   hash: hash,
                   nonce: 1,
                   gas_price: 20_000_000_000
                 },
                 contract.authority_addr,
                 contract.contract_addr
               )

             assert_block_getter_down()
           end) =~ inspect(:tx_execution)

    invalid_block_event =
      Client.encode(%Event.InvalidBlock{
        error_type: :tx_execution,
        hash: hash,
        number: 1000
      })

    assert_push("invalid_block", ^invalid_block_event)

    JSONRPC2.Servers.HTTP.shutdown(BadChildChainTransaction)
  end

  defp assert_block_getter_down do
    :ok = TestHelper.wait_for_process(Process.whereis(OmiseGOWatcher.BlockGetter))
  end

  defp get_utxo(%{addr: address}) do
    {:ok, address_encode} = Crypto.encode_address(address)
    decoded_resp = TestHelper.rest_call(:get, "account/utxo?address=#{address_encode}")
    decoded_resp["utxos"]
  end
end

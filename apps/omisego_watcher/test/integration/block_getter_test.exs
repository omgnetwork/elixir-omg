defmodule OmiseGOWatcher.BlockGetterTest do
  use ExUnitFixtures
  use ExUnit.Case, async: false
  use OmiseGO.API.Fixtures
  use Plug.Test

  alias OmiseGO.API
  alias OmiseGO.Eth
  alias OmiseGO.JSONRPC.Client
  alias OmiseGOWatcher.BlockGetter
  alias OmiseGOWatcher.TestHelper

  @moduletag :integration

  @timeout 20_000
  @block_offset 1_000_000_000
  @eth OmiseGO.API.Crypto.zero_address()

  defp deposit_to_child_chain(to, value, contract) do
    {:ok, destiny_enc} = Eth.DevHelpers.import_unlock_fund(to)
    Eth.DevHelpers.deposit(value, 0, destiny_enc, contract.contract_addr)
  end

  defp wait_for_deposit({:ok, deposit_tx_hash}, contract) do
    {:ok, receipt} = Eth.WaitFor.eth_receipt(deposit_tx_hash)
    deposit_blknum = Eth.DevHelpers.deposit_blknum_from_receipt(receipt)

    post_deposit_child_block =
      deposit_blknum - 1 +
        (Application.get_env(:omisego_api, :ethereum_event_block_finality_margin) + 1) *
          Application.get_env(:omisego_eth, :child_block_interval)

    {:ok, _} =
      Eth.DevHelpers.wait_for_current_child_block(post_deposit_child_block, true, 60_000, contract.contract_addr)

    deposit_blknum
  end

  defp wait_for_block_getter_get_block(block_number) do
    block_has_been_reached = fn ->
      # TODO use event system
      case GenServer.call(BlockGetter, :get_height, 10_000) < block_number do
        true -> :repeat
        false -> {:ok, block_number}
      end
    end

    fn -> Eth.WaitFor.repeat_until_ok(block_has_been_reached) end
    |> Task.async()
    |> Task.await(@timeout)
  end

  @tag fixtures: [:watcher_sandbox, :contract, :geth, :child_chain, :root_chain_contract_config, :alice, :bob]
  test "get the blocks from child chain after transaction and start exit",
       %{contract: contract, alice: alice, bob: bob} do
    deposit_blknum = alice |> deposit_to_child_chain(10, contract) |> wait_for_deposit(contract)
    # TODO remove slpeep after synch deposit synch
    :timer.sleep(100)
    tx = API.TestHelper.create_encoded([{deposit_blknum, 0, 0, alice}], @eth, [{alice, 7}, {bob, 3}])
    {:ok, %{"blknum" => block_nr}} = Client.call(:submit, %{transaction: tx})

    wait_for_block_getter_get_block(block_nr)

    encode_tx = Client.encode(tx)

    assert [%{"amount" => 3, "blknum" => block_nr, "oindex" => 0, "txindex" => 0, "txbytes" => encode_tx}] ==
             get_utxo(bob)

    assert [%{"amount" => 7, "blknum" => block_nr, "oindex" => 0, "txindex" => 0, "txbytes" => encode_tx}] ==
             get_utxo(alice)

    %{
      utxo_pos: utxo_pos,
      tx_bytes: tx_bytes,
      proof: proof,
      sigs: sigs
    } = compose_utxo_exit(block_nr, 0, 0)

    alice_address = "0x" <> Base.encode16(alice.addr, case: :lower)

    {:ok, txhash} =
      Eth.start_exit(
        utxo_pos * @block_offset,
        tx_bytes,
        proof,
        sigs,
        1,
        alice_address,
        contract.contract_addr
      )

    {:ok, _} = Eth.WaitFor.eth_receipt(txhash, @timeout)

    {:ok, height} = Eth.get_ethereum_height()

    assert {:ok, [%{amount: 7, blknum: block_nr, oindex: 0, owner: alice_address, txindex: 0, token: @eth}]} ==
             Eth.get_exits(0, height, contract.contract_addr)
  end

  @tag fixtures: [:watcher_sandbox, :contract, :alice]
  test "diffrent hash send by child chain", %{alice: alice, contract: contract} do
    defmodule BadChildChainHash do
      use JSONRPC2.Server.Handler

      def handle_request(_, _) do
        %{hash: "8BE7BCF154F9484A7762268C93B02D2507EE8475CF02F8F94A3032A3BE5FC7D8", transactions: []}
      end
    end

    JSONRPC2.Servers.HTTP.http(BadChildChainHash, port: Application.get_env(:omisego_jsonrpc, :omisego_api_rpc_port))

    {:ok, _txhash} =
      Eth.submit_block(
        %Eth.BlockSubmission{
          num: 1_000,
          hash: OmiseGO.API.Crypto.zero_address(),
          nonce: 1,
          gas_price: 20_000_000_000
        },
        contract.authority_addr,
        contract.contract_addr
      )

    # TODO receive information about errro
    TestHelper.wait_for_process(Process.whereis(:omisego_watcher))

    JSONRPC2.Servers.HTTP.shutdown(BadChildChainHash)
  end

  @tag fixtures: [:watcher_sandbox, :contract, :alice]
  test "bad transaction", %{alice: alice, contract: contract} do
    defmodule BadChildChainTransaction do
      use JSONRPC2.Server.Handler

      def handle_request(_, _) do
        %{
          hash: "8BE7BCF154F9484A7762268C93B02D2507EE8475CF02F8F94A3032A3BE5FC7D8",
          transactions: [
            "F8D28207D1808080808094000000000000000000000000000000000000000094DF97E6CC462B33C784214708B3365B42768AC9848202BC948315C85F760DBD875395B2169EB2BFCCE3FD855B81C8B8415050FC74F82E49684D3D14F42AA161714FADDB3BC7F78DE75CB92903CCEE024A73292302E69230C45E7967F5F0630E4247C733D2A8B3AA9DB518E8B680F124241CB8410000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
            "F8D38279198080808080940000000000000000000000000000000000000000948315C85F760DBD875395B2169EB2BFCCE3FD855B8201F494B882E2B1513B5CEC838DCBE55D3F38FB61EEEBF0820190B84165CABB615E2F1969CFD2F81945E1DBD47AB471183728EB5586482A44ECD9550325B75545CCB5DDD17BE0322A7D978379458DC31435FACBFF4A7275D6909D93321CB8410000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"
          ]
        }
      end
    end

    JSONRPC2.Servers.HTTP.http(
      BadChildChainTransaction,
      port: Application.get_env(:omisego_jsonrpc, :omisego_api_rpc_port)
    )

    {:ok, _txhash} =
      Eth.submit_block(
        %Eth.BlockSubmission{
          num: 1_000,
          hash: Base.decode16!("8BE7BCF154F9484A7762268C93B02D2507EE8475CF02F8F94A3032A3BE5FC7D8"),
          nonce: 1,
          gas_price: 20_000_000_000
        },
        contract.authority_addr,
        contract.contract_addr
      )

    TestHelper.wait_for_process(Process.whereis(:omisego_watcher))
    # TODO receive information about errro
    JSONRPC2.Servers.HTTP.shutdown(BadChildChainTransaction)
  end

  defp get_utxo(%{addr: address}) do
    decoded_resp = TestHelper.rest_call(:get, "account/utxo?address=#{Client.encode(address)}")
    decoded_resp["utxos"]
  end

  defp compose_utxo_exit(block_height, txindex, oindex) do
    decoded_resp =
      TestHelper.rest_call(
        :get,
        "account/utxo/compose_exit?block_height=#{block_height}&txindex=#{txindex}&oindex=#{oindex}"
      )

    {:ok, tx_bytes} = Client.decode(:bitstring, decoded_resp["tx_bytes"])
    {:ok, proof} = Client.decode(:bitstring, decoded_resp["proof"])
    {:ok, sigs} = Client.decode(:bitstring, decoded_resp["sigs"])

    %{
      utxo_pos: decoded_resp["utxo_pos"],
      tx_bytes: tx_bytes,
      proof: proof,
      sigs: sigs
    }
  end
end

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
  alias OmiseGOWatcher.Integration.TestHelper, as: IntegrationTest
  alias OmiseGOWatcher.TestHelper, as: Test

  @moduletag :integration

  @timeout 20_000
  @block_offset 1_000_000_000
  @eth OmiseGO.API.Crypto.zero_address()

  @tag fixtures: [:watcher_sandbox, :contract, :geth, :child_chain, :root_chain_contract_config, :alice, :bob]
  test "get the blocks from child chain after transaction and start exit",
       %{contract: contract, alice: alice, bob: bob} do
    deposit_blknum = IntegrationTest.deposit_to_child_chain(alice, 10, contract)
    # TODO remove slpeep after synch deposit synch
    :timer.sleep(100)
    tx = API.TestHelper.create_encoded([{deposit_blknum, 0, 0, alice}], @eth, [{alice, 7}, {bob, 3}])
    {:ok, %{"blknum" => block_nr}} = Client.call(:submit, %{transaction: tx})

    IntegrationTest.wait_until_block_getter_fetches_block(block_nr, @timeout)

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
    } = IntegrationTest.compose_utxo_exit(block_nr, 0, 0)

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

    {:ok, %{"status" => "0x1"}} = Eth.WaitFor.eth_receipt(txhash, @timeout)

    {:ok, height} = Eth.get_ethereum_height()

    assert {:ok, [%{amount: 7, blknum: block_nr, oindex: 0, owner: alice_address, txindex: 0, token: @eth}]} ==
             Eth.get_exits(0, height, contract.contract_addr)
  end

  @tag fixtures: [:watcher_sandbox, :geth, :contract, :alice]
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
          hash: @eth,
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

  @tag fixtures: [:watcher_sandbox, :contract, :geth]
  test "bad transaction with not existing utxo", %{contract: contract} do
    defmodule BadChildChainTransaction do
      use JSONRPC2.Server.Handler
      alias OmiseGO.API
      alias OmiseGO.API.State.Transaction.{Recovered, Signed}

      def block_with_incorrect_transaction do
        alice = %{
          addr: <<24, 220, 32, 219, 73, 254, 191, 110, 255, 199, 70, 131, 226, 124, 105, 88, 140, 140, 20, 83>>,
          priv:
            <<28, 154, 156, 164, 46, 175, 188, 174, 214, 255, 70, 155, 142, 175, 44, 193, 21, 122, 229, 84, 131, 20,
              125, 164, 97, 75, 230, 92, 255, 5, 25, 96>>
        }

        recovered =
          API.TestHelper.create_recovered([{1, 0, 0, alice}], OmiseGO.API.Crypto.zero_address(), [{alice, 10}])

        %API.Block{transactions: [recovered], number: 1} |> API.Block.merkle_hash()
      end

      def handle_request(_, _) do
        %API.Block{
          transactions: [%Recovered{signed_tx: %Signed{signed_tx_bytes: signed_tx_bytes}}]
        } = block = block_with_incorrect_transaction()

        OmiseGO.JSONRPC.Client.encode(%{block | transactions: [signed_tx_bytes]})
      end
    end

    JSONRPC2.Servers.HTTP.http(
      BadChildChainTransaction,
      port: Application.get_env(:omisego_jsonrpc, :omisego_api_rpc_port)
    )

    %API.Block{hash: hash} = BadChildChainTransaction.block_with_incorrect_transaction()

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

    TestHelper.wait_for_process(Process.whereis(:omisego_watcher))
    # TODO receive information about errro
    JSONRPC2.Servers.HTTP.shutdown(BadChildChainTransaction)
  end

  defp get_utxo(%{addr: address}) do
    decoded_resp = TestHelper.rest_call(:get, "account/utxo?address=#{Client.encode(address)}")
    decoded_resp["utxos"]
  end
end

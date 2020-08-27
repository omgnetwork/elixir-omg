# Copyright 2019-2020 OmiseGO Pte Ltd
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

defmodule OMG.ChildChain.Integration.HappyPathTest do
  @moduledoc """
  Tests a simple happy path of all the pieces working together
  """

  use ExUnitFixtures
  use ExUnit.Case, async: false
  use Plug.Test

  require OMG.Utxo

  alias OMG.Block
  alias OMG.Eth.Client
  alias OMG.Eth.Configuration
  alias OMG.State.Transaction
  alias OMG.Utils.HttpRPC.Encoding
  alias OMG.Utxo
  alias Support.DevHelper
  alias Support.Integration.DepositHelper
  alias Support.RootChainHelper

  require Logger
  @moduletag :live_childchain

  # bumping the timeout to two minutes for the tests here, as they do a lot of transactions to Ethereum to test
  @moduletag timeout: 120_000

  @eth OMG.Eth.zero_address()
  @interval Configuration.child_block_interval()
  @sleep_retry_sec 1000
  @retry_count 50
  @deposit_finality_margin 10

  test "check that unspent funds can be exited with in-flight exits" do
    [alice] = take_accounts(1)
    deposit_blknum = prepare_deposits(alice)
    exiters_finality_margin = @deposit_finality_margin + 1
    {:ok, eth_height} = Client.get_ethereum_height()
    DevHelper.wait_for_root_chain_block(eth_height + exiters_finality_margin)
    # create transaction, submit, wait for block publication
    tx = OMG.TestHelper.create_signed([{deposit_blknum, 0, 0, alice}], @eth, [{alice, 5}, {alice, 4}])
    {:ok, %{"blknum" => blknum, "txindex" => txindex}} = tx |> Transaction.Signed.encode() |> submit_transaction()

    post_spend_child_block = blknum + @interval
    {:ok, _} = DevHelper.wait_for_next_child_block(post_spend_child_block)

    # create transaction & data for in-flight exit, start in-flight exit
    %Transaction.Signed{sigs: in_flight_tx_sigs} =
      in_flight_tx =
      OMG.TestHelper.create_signed([{blknum, txindex, 0, alice}, {blknum, txindex, 1, alice}], @eth, [{alice, 8}])

    fee_claimer = OMG.Configuration.fee_claimer_address()
    fee_tx = OMG.TestHelper.create_encoded_fee_tx(blknum, fee_claimer, @eth, 1)

    proof = Block.inclusion_proof([Transaction.Signed.encode(tx), fee_tx], txindex)
    # Process.sleep(25000)
    {:ok, %{"status" => "0x1", "blockNumber" => eth_height}} =
      RootChainHelper.in_flight_exit(
        Transaction.raw_txbytes(in_flight_tx),
        get_input_txs([tx, tx]),
        [
          Utxo.Position.encode(Utxo.position(blknum, txindex, 0)),
          Utxo.Position.encode(Utxo.position(blknum, txindex, 1))
        ],
        [proof, proof],
        in_flight_tx_sigs,
        alice.addr
      )
      |> DevHelper.transact_sync!()

    exiters_finality_margin = @deposit_finality_margin + 10
    DevHelper.wait_for_root_chain_block(eth_height + exiters_finality_margin)

    # check that output of 1st transaction was spend by in-flight exit
    tx_double_spend = OMG.TestHelper.create_encoded([{blknum, txindex, 0, alice}], @eth, [{alice, 2}, {alice, 3}])
    assert {:error, %{"code" => "submit:utxo_not_found"}} = submit_transaction(tx_double_spend)

    deposit_blknum = DepositHelper.deposit_to_child_chain(alice.addr, 10)
    exiters_finality_margin = @deposit_finality_margin + 1
    {:ok, eth_height} = Client.get_ethereum_height()
    DevHelper.wait_for_root_chain_block(eth_height + exiters_finality_margin)

    %Transaction.Signed{sigs: sigs} =
      in_flight_tx2 = OMG.TestHelper.create_signed([{deposit_blknum, 0, 0, alice}], @eth, [{alice, 6}, {alice, 3}])

    {:ok, %{"blknum" => blknum}} = in_flight_tx2 |> Transaction.Signed.encode() |> submit_transaction()

    in_flight_tx2_rawbytes = Transaction.raw_txbytes(in_flight_tx2)

    # create exit data for tx spending deposit & start in-flight exit
    deposit_tx = OMG.TestHelper.create_signed([], @eth, [{alice, 10}])
    proof = Block.inclusion_proof([Transaction.Signed.encode(deposit_tx)], 0)

    {:ok, %{"status" => "0x1", "blockNumber" => eth_height}} =
      RootChainHelper.in_flight_exit(
        in_flight_tx2_rawbytes,
        get_input_txs([deposit_tx]),
        [Utxo.Position.encode(Utxo.position(deposit_blknum, 0, 0))],
        [proof],
        sigs,
        alice.addr
      )
      |> DevHelper.transact_sync!()

    DevHelper.wait_for_root_chain_block(eth_height + 2)

    # piggyback only to the first transaction's output & wait for finalization
    {:ok, %{"status" => "0x1", "blockNumber" => eth_height}} =
      in_flight_tx2_rawbytes
      |> RootChainHelper.piggyback_in_flight_exit_on_output(0, alice.addr)
      |> DevHelper.transact_sync!()

    DevHelper.wait_for_root_chain_block(eth_height + exiters_finality_margin)

    # check that deposit & 1st, piggybacked output are spent, 2nd output is not
    deposit_double_spend =
      OMG.TestHelper.create_encoded([{deposit_blknum, 0, 0, alice}], @eth, [{alice, 7}, {alice, 3}])

    assert {:error, %{"code" => "submit:utxo_not_found"}} = submit_transaction(deposit_double_spend)

    first_output_double_spend = OMG.TestHelper.create_encoded([{blknum, 0, 0, alice}], @eth, [{alice, 7}])
    assert {:error, %{"code" => "submit:utxo_not_found"}} = submit_transaction(first_output_double_spend)

    second_output_spend = OMG.TestHelper.create_encoded([{blknum, 0, 1, alice}], @eth, [{alice, 2}])
    assert {:ok, _} = submit_transaction(second_output_spend)
  end

  # @tag fixtures: [:alice, :alice_deposits]
  test "check in-flight exit input piggybacking is ignored by the child chain" do
    [alice] = take_accounts(1)
    deposit_blknum = prepare_deposits(alice)
    # create transaction, submit, wait for block publication
    tx = OMG.TestHelper.create_signed([{deposit_blknum, 0, 0, alice}], @eth, [{alice, 9}])
    {:ok, %{"blknum" => blknum, "txindex" => txindex}} = tx |> Transaction.Signed.encode() |> submit_transaction()

    %Transaction.Signed{sigs: in_flight_tx_sigs} =
      in_flight_tx = OMG.TestHelper.create_signed([{blknum, txindex, 0, alice}], @eth, [{alice, 5}])

    # We need to consider fee tx in block, as 10 ETH deposited = 9 transferred with `tx` + 1 collected as fees
    fee_claimer = OMG.Configuration.fee_claimer_address()
    fee_tx = OMG.TestHelper.create_encoded_fee_tx(blknum, fee_claimer, @eth, 1)

    proof = Block.inclusion_proof([Transaction.Signed.encode(tx), fee_tx], 0)

    {:ok, %{"status" => "0x1"}} =
      RootChainHelper.in_flight_exit(
        Transaction.raw_txbytes(in_flight_tx),
        get_input_txs([tx]),
        [Utxo.Position.encode(Utxo.position(blknum, txindex, 0))],
        [proof],
        in_flight_tx_sigs,
        alice.addr
      )
      |> DevHelper.transact_sync!()

    {:ok, %{"status" => "0x1", "blockNumber" => eth_height}} =
      in_flight_tx
      |> Transaction.raw_txbytes()
      |> RootChainHelper.piggyback_in_flight_exit_on_input(0, alice.addr)
      |> DevHelper.transact_sync!()

    deposit_finality_margin = 10
    exiters_finality_margin = deposit_finality_margin + 1
    DevHelper.wait_for_root_chain_block(eth_height + exiters_finality_margin)
    # sanity check everything still lives
    assert {:error, %{"code" => "submit:utxo_not_found"}} = tx |> Transaction.Signed.encode() |> submit_transaction()
  end

  # @tag fixtures: [:alice]
  test "check submitted fee transaction is rejected" do
    [alice] = take_accounts(1)
    fee_tx = OMG.TestHelper.create_encoded_fee_tx(1000, alice.addr, @eth, 1000)

    assert {:error, %{"code" => "submit:transaction_not_supported"}} = submit_transaction(fee_tx)
  end

  defp submit_transaction(tx) do
    "/transaction.submit"
    |> rpc_call(%{transaction: Encoding.to_hex(tx)})
    |> get_body_data()
  end

  defp get_body_data(resp_body) do
    {
      if(resp_body["success"], do: :ok, else: :error),
      resp_body["data"]
    }
  end

  defp get_input_txs(txs), do: Enum.map(txs, &Transaction.raw_txbytes/1)

  defp rpc_call(path, params_or_body) do
    {:ok, response} =
      HTTPoison.post("http://localhost:9656" <> path, Jason.encode!(params_or_body), [
        {"Content-Type", "application/json"}
      ])

    IO.inspect(response)
    Jason.decode!(response.body)
  end

  defp take_accounts(number_of_accounts) do
    1..number_of_accounts
    |> Task.async_stream(fn _ -> account() end,
      timeout: 120_000,
      on_timeout: :kill_task,
      max_concurrency: System.schedulers_online() * 2
    )
    |> Enum.map(fn {:ok, result} -> result end)
    |> Enum.map(fn {addr, priv} -> %{addr: Encoding.from_hex!(addr), priv: Encoding.from_hex!("0x" <> priv)} end)
  end

  defp account() do
    tick_acc = generate_entity()
    account_priv_enc = Base.encode16(tick_acc.priv)
    passphrase = "dev.period"

    {:ok, addr} = create_account_from_secret(account_priv_enc, passphrase)

    {:ok, [faucet | _]} = Ethereumex.HttpClient.eth_accounts()

    data = %{from: faucet, to: addr, value: to_hex(1_000_000 * trunc(:math.pow(10, 9 + 5)))}

    {:ok, receipt_hash} = Ethereumex.HttpClient.eth_send_transaction(data)

    wait_on_receipt_confirmed(receipt_hash)

    {:ok, true} = Ethereumex.HttpClient.request("personal_unlockAccount", [addr, passphrase, 0], [])

    {addr, account_priv_enc}
  end

  defp generate_entity() do
    {:ok, priv} = generate_private_key()
    {:ok, pub} = generate_public_key(priv)
    {:ok, address} = generate_address(pub)
    %{priv: priv, addr: address}
  end

  defp generate_private_key(), do: {:ok, :crypto.strong_rand_bytes(32)}

  defp generate_public_key(<<priv::binary-size(32)>>) do
    {:ok, der_pub} = get_public_key(priv)
    {:ok, der_to_raw(der_pub)}
  end

  defp get_public_key(private_key) do
    case :libsecp256k1.ec_pubkey_create(private_key, :uncompressed) do
      {:ok, public_key} -> {:ok, public_key}
      {:error, reason} -> {:error, to_string(reason)}
    end
  end

  defp der_to_raw(<<4::integer-size(8), data::binary>>), do: data

  defp generate_address(<<pub::binary-size(64)>>) do
    <<_::binary-size(12), address::binary-size(20)>> = hash(pub)
    {:ok, address}
  end

  defp hash(message), do: ExthCrypto.Hash.hash(message, ExthCrypto.Hash.kec())

  defp create_account_from_secret(secret, passphrase) do
    Ethereumex.HttpClient.request("personal_importRawKey", [secret, passphrase], [])
  end

  def wait_on_receipt_confirmed(receipt_hash) do
    wait_on_receipt_status(receipt_hash, "0x1", @retry_count)
  end

  defp wait_on_receipt_status(receipt_hash, _status, 0), do: get_transaction_receipt(receipt_hash)

  defp wait_on_receipt_status(receipt_hash, status, counter) do
    _ = Logger.info("Waiting on #{receipt_hash} for status #{status} for #{counter} seconds")
    do_wait_on_receipt_status(receipt_hash, status, counter)
  end

  defp do_wait_on_receipt_status(receipt_hash, expected_status, counter) do
    response = get_transaction_receipt(receipt_hash)
    # response might break with {:error, :closed} or {:error, :socket_closed_remotely}
    case response do
      {:ok, nil} ->
        Process.sleep(@sleep_retry_sec)
        do_wait_on_receipt_status(receipt_hash, expected_status, counter - 1)

      {:error, _} ->
        Process.sleep(@sleep_retry_sec)
        do_wait_on_receipt_status(receipt_hash, expected_status, counter - 1)

      {:ok, %{"status" => ^expected_status} = resp} ->
        revert_reason(resp)
        resp

      {:ok, resp} ->
        revert_reason(resp)
        resp
    end
  end

  defp get_transaction_receipt(receipt_hash) do
    Ethereumex.HttpClient.eth_get_transaction_receipt(receipt_hash)
  end

  defp revert_reason(%{"status" => "0x1"}), do: :ok

  defp revert_reason(%{"status" => "0x0"} = response) do
    {:ok, tx} = Ethereumex.HttpClient.eth_get_transaction_by_hash(response["transactionHash"])

    {:ok, reason} = Ethereumex.HttpClient.eth_call(Map.put(tx, "data", tx["input"]), tx["blockNumber"])
    hash = response["transactionHash"]

    _ =
      Logger.info(
        "Revert reason for #{inspect(hash)}: revert string: #{inspect(decode_reason(reason))}, revert binary: #{
          inspect(to_binary(reason), limit: :infinity)
        }"
      )
  end

  defp decode_reason(reason) do
    # https://ethereum.stackexchange.com/questions/48383/how-to-receive-revert-reason-for-past-transactions
    reason |> String.split_at(138) |> elem(1) |> Base.decode16!(case: :lower) |> String.chunk(:printable)
  end

  def to_hex(binary) when is_binary(binary),
    do: "0x" <> Base.encode16(binary, case: :lower)

  def to_hex(integer) when is_integer(integer),
    do: "0x" <> Integer.to_string(integer, 16)

  def to_binary(hex) do
    hex
    |> String.replace_prefix("0x", "")
    |> String.upcase()
    |> Base.decode16!()
  end

  defp prepare_deposits(alice) do
    some_value = 10

    deposit_blknum = DepositHelper.deposit_to_child_chain(alice.addr, some_value)
    deposit_blknum
  end
end

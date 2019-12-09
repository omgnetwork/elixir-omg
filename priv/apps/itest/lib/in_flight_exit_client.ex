defmodule Itest.InFlightExitClient do
  @moduledoc """
  """

  alias Itest.Transactions.Currency
  alias Itest.Transactions.Encoding
  alias Itest.Transactions.PaymentType
  alias Itest.Client
  alias WatcherSecurityCriticalAPI.Connection, as: Watcher
  alias WatcherSecurityCriticalAPI.Api.InFlightExit
  alias WatcherSecurityCriticalAPI.Model.InFlightExitTxBytesBodySchema

  import Itest.Poller, only: [wait_on_receipt_confirmed: 2]
  require Logger

  @ife_bond_size 37_000_000_000_000_000
  @ife_gas 2_000_000
  @ife_gas_price 1_000_000_000
  @retry_count 120
  @min_exit_period 50_000
  @gas_process_exit 5_712_388
  @gas_process_exit_price 1_000_000_000
  @gas_add_exit_queue 800_000

  @gas_piggyback 1_000_000
  @piggyback_bond 28_000_000_000_000_000

  defstruct [
    :add_exit_queue_hash,
    :address,
    :address_key,
    :exit_data,
    :exit_game_contract_address,
    :exit_id,
    :piggyback_input_hash,
    :process_exit_receipt_hash,
    :receiver_address,
    :sign_hash,
    :signed_txbytes,
    :start_in_flight_exit,
    :txbytes
  ]

  def start_in_flight_exit(sender_address, sender_key, receiver_address) do
    %__MODULE__{address: sender_address, address_key: sender_key, receiver_address: receiver_address}
    |> create_transaction()
    |> sign_transaction()
    |> add_exit_queue()
    |> get_exit_data()
    |> get_exit_game_contract_address()
    |> do_in_flight_exit()
    |> get_in_flight_exit_id()
    |> piggyback_input()
    |> process_exit()
  end


  defp get_exit_data(%{signed_txbytes: txbytes} = se) do
    payload = %InFlightExitTxBytesBodySchema{txbytes: txbytes}
    {:ok, response} = InFlightExit.in_flight_exit_get_data(Watcher.new(), payload)

    exit_data = Jason.decode!(response.body)["data"]
    IO.inspect(exit_data)
    %{se | exit_data: exit_data}
  end

  defp create_transaction(%{address: address, receiver_address: receiver_address} = se) do
    {:ok, [sign_hash, _typed_data, txbytes]} =
      Client.create_transaction(Currency.to_wei(1), address, receiver_address, Currency.ether())

    %{se | txbytes: txbytes, sign_hash: sign_hash}
  end

  defp sign_transaction(%{address_key: address_key, txbytes: txbytes, sign_hash: sign_hash} = se) do
    [type, inputs, outputs, metadata] = txbytes |> Encoding.to_binary() |> ExRLP.decode()

    signature = sign_hash |> Encoding.to_binary() |> Encoding.signature_digest(address_key)

    rlp_list = [[signature], type, inputs, outputs, metadata]

    signed_txbytes = rlp_list |> ExRLP.encode() |> Encoding.to_hex()

    %{se | signed_txbytes: signed_txbytes}
  end

  defp get_exit_game_contract_address(se) do
    data = ABI.encode("exitGames(uint256)", [PaymentType.simple_payment_transaction()])
    {:ok, result} = Ethereumex.HttpClient.eth_call(%{to: Itest.Account.plasma_framework(), data: Encoding.to_hex(data)})

    exit_game_contract_address =
      result
      |> Encoding.to_binary()
      |> ABI.TypeDecoder.decode([:address])
      |> hd()
      |> Encoding.to_hex()

    %{se | exit_game_contract_address: exit_game_contract_address}
  end

  defp do_in_flight_exit(%{address: address, exit_data: exit_data, exit_game_contract_address: exit_game_contract_address} = se) do
    in_flight_tx = exit_data["in_flight_tx"] |> Encoding.to_binary()
    in_flight_tx_sigs = Enum.map(exit_data["in_flight_tx_sigs"], &Encoding.to_binary(&1))
    input_txs = Enum.map(exit_data["input_txs"], &Encoding.to_binary(&1))
    input_txs_inclusion_proofs = Enum.map(exit_data["input_txs_inclusion_proofs"], &Encoding.to_binary(&1))
    input_utxos_pos = Enum.map(exit_data["input_utxos_pos"], &:binary.encode_unsigned(&1))

    # NOTE: hardcoded for now, we're talking to a particular exit game so this is fixed
    optional_bytes_array = List.duplicate("", Enum.count(input_txs))

     values = [
      {in_flight_tx, input_txs, input_utxos_pos, optional_bytes_array, input_txs_inclusion_proofs, optional_bytes_array,
       in_flight_tx_sigs, optional_bytes_array}]

    IO.inspect("----building ife----")
    IO.inspect(values)

    data =
      ABI.encode(
        "startInFlightExit((bytes,bytes[],uint256[],bytes[],bytes[],bytes[],bytes[],bytes[]))",
        values)

    txmap = %{
      from: address,
      to: exit_game_contract_address,
      value: Encoding.to_hex(@ife_bond_size),
      data: Encoding.to_hex(data),
      gas: Encoding.to_hex(@ife_gas * 2),
      gasPrice: Encoding.to_hex(@ife_gas_price)
    }

    {:ok, receipt_hash} = Ethereumex.HttpClient.eth_send_transaction(txmap)
    wait_on_receipt_confirmed(receipt_hash, @retry_count)

    IO.inspect("---started in flight exit ---")
    IO.inspect(receipt_hash)

    %{se | start_in_flight_exit: receipt_hash}
  end

  defp get_in_flight_exit_id(%{exit_data: exit_data, exit_game_contract_address: exit_game_contract_address} = se) do
    txbytes = exit_data["in_flight_tx"] |> Encoding.to_binary()
    data = ABI.encode("getInFlightExitId(bytes)", [txbytes])
    {:ok, result} = Ethereumex.HttpClient.eth_call(%{to: exit_game_contract_address, data: Encoding.to_hex(data)})
    exit_id =
      result
      |> Encoding.to_binary()
      |> ABI.TypeDecoder.decode([{:uint, 128}])
      |> hd()

    IO.inspect("---- exit id ----")
    IO.inspect(exit_id)

    %{se | exit_id: exit_id}
  end

  defp piggyback_input(%{
    address: address,
    exit_data: exit_data, 
    exit_game_contract_address: exit_game_contract_address
  } = se) do

    Process.sleep(10_000)

    IO.inspect("---started piggyback ---")
    in_flight_tx = exit_data["in_flight_tx"] |> Encoding.to_binary()

    data =
      ABI.encode(
        "piggybackInFlightExitOnInput((bytes,uint16))",
        [{in_flight_tx, 0}]
      )

    txmap = %{
      from: address,
      to: exit_game_contract_address,
      value: Encoding.to_hex(@piggyback_bond),
      data: Encoding.to_hex(data),
      gas: Encoding.to_hex(@gas_piggyback)
    }

    {:ok, receipt_hash} = Ethereumex.HttpClient.eth_send_transaction(txmap)
    wait_on_receipt_confirmed(receipt_hash, @retry_count)

    IO.inspect(receipt_hash)

    %{se | piggyback_input_hash: receipt_hash}
  end

  defp process_exit(%__MODULE__{address: address} = se) do
    Process.sleep(@min_exit_period)

    IO.inspect("attempting process exit...")

    # TODO this should use the standard_exit_id instead and figure out
    # why this isn't the topExitID on clean slate.
    data =
      ABI.encode(
        "processExits(uint256,address,uint160,uint256)",
        [Itest.Account.vault_id(Currency.ether()), Currency.ether(), 0, 1]
      )

    txmap = %{
      from: address,
      to: Itest.Account.plasma_framework(),
      value: Encoding.to_hex(0),
      data: Encoding.to_hex(data),
      gas: Encoding.to_hex(@gas_process_exit),
      gasPrice: Encoding.to_hex(@gas_process_exit_price)
    }

    {:ok, receipt_hash} = Ethereumex.HttpClient.eth_send_transaction(txmap)
    wait_on_receipt_confirmed(receipt_hash, @retry_count)

    %{se | process_exit_receipt_hash: receipt_hash}
  end

  defp add_exit_queue(%__MODULE__{} = se) do
    if has_exit_queue?() do
      _ = Logger.info("Exit queue was already added.")
      se
    else
      _ = Logger.info("Exit queue missing. Adding...")

      data =
        ABI.encode(
          "addExitQueue(uint256,address)",
          [Itest.Account.vault_id(Currency.ether()), Currency.ether()]
        )

      txmap = %{
        from: se.address,
        to: Itest.Account.plasma_framework(),
        value: Encoding.to_hex(0),
        data: Encoding.to_hex(data),
        gas: Encoding.to_hex(@gas_add_exit_queue)
      }

      {:ok, receipt_hash} = Ethereumex.HttpClient.eth_send_transaction(txmap)
      wait_on_receipt_confirmed(receipt_hash, @retry_count)
      wait_for_exit_queue(se, @retry_count)
      %{se | add_exit_queue_hash: receipt_hash}
    end
  end

  defp wait_for_exit_queue(%__MODULE__{} = _se, 0), do: exit(1)

  defp wait_for_exit_queue(%__MODULE__{} = se, counter) do
    if has_exit_queue?() do
      se
    else
      Process.sleep(@sleep_retry_sec)
      wait_for_exit_queue(se, counter - 1)
    end
  end

  defp has_exit_queue?() do
    data =
      ABI.encode(
        "hasExitQueue(uint256,address)",
        [Itest.Account.vault_id(Currency.ether()), Currency.ether()]
      )

    {:ok, receipt_enc} =
      Ethereumex.HttpClient.eth_call(%{to: Itest.Account.plasma_framework(), data: Encoding.to_hex(data)})

    receipt_enc
    |> Encoding.to_binary()
    |> ABI.TypeDecoder.decode([:bool])
    |> hd()
  end
end

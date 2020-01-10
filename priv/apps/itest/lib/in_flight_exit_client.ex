defmodule Itest.InFlightExitClient do
  @moduledoc """
  Client to run the in flight exit flow
  """

  alias Itest.ApiModel.IfeExitData
  alias Itest.Client
  alias Itest.Transactions.Currency
  alias Itest.Transactions.Encoding
  alias Itest.Transactions.PaymentType
  alias WatcherSecurityCriticalAPI.Api.InFlightExit
  alias WatcherSecurityCriticalAPI.Connection, as: Watcher
  alias WatcherSecurityCriticalAPI.Model.InFlightExitTxBytesBodySchema

  import Itest.Poller, only: [wait_on_receipt_confirmed: 1, pull_api_until_successful: 4]
  require Logger
  use Bitwise

  @ife_gas 2_000_000
  @ife_gas_price 1_000_000_000
  @retry_count 120
  @gas_add_exit_queue 800_000
  @gas_piggyback 1_000_000
  @sleep_retry_sec 2_000
  @gas_process_exit 5_712_388
  @gas_process_exit_price 1_000_000_000

  defstruct [
    :address,
    :address_key,
    :exit_data,
    :exit_game_contract_address,
    :ife_exit_id,
    :piggyback_input_hash,
    :process_exit_receipt_hash,
    :ife_exit_ids,
    :add_exit_queue_hash,
    :receiver_address,
    :sign_hash,
    :signed_txbytes,
    :in_flight_exit_bond_size,
    :start_in_flight_exit,
    :piggyback_bond_size,
    :txbytes
  ]

  def start_in_flight_exit(sender_address, sender_key, receiver_address) do
    _ = Logger.info("Start in flight exit...")

    %__MODULE__{address: sender_address, address_key: sender_key, receiver_address: receiver_address}
    |> create_transaction()
    |> sign_transaction()
    |> get_exit_data()
    |> get_exit_game_contract_address()
    |> add_exit_queue()
    |> get_in_flight_exit_bond_size()
    |> do_in_flight_exit()
    |> get_in_flight_exit_id()
    |> get_in_flight_exits()
    |> get_piggyback_bond_size()
    |> piggyback_input()
    |> wait_for_exit_period()
    |> process_exit()
  end

  defp create_transaction(%{address: address, receiver_address: receiver_address} = ife) do
    {:ok, [sign_hash, _typed_data, txbytes]} =
      Client.create_transaction(Currency.to_wei(1), address, receiver_address, Currency.ether())

    %{ife | txbytes: txbytes, sign_hash: sign_hash}
  end

  defp sign_transaction(%{address_key: address_key, txbytes: txbytes, sign_hash: sign_hash} = ife) do
    [type, inputs, outputs, "", metadata] = txbytes |> Encoding.to_binary() |> ExRLP.decode()

    signature = sign_hash |> Encoding.to_binary() |> Encoding.signature_digest(address_key)

    rlp_list = [[signature], type, inputs, outputs, "", metadata]

    signed_txbytes = rlp_list |> ExRLP.encode() |> Encoding.to_hex()

    %{ife | signed_txbytes: signed_txbytes}
  end

  defp get_exit_data(%{signed_txbytes: txbytes} = ife) do
    payload = %InFlightExitTxBytesBodySchema{txbytes: txbytes}
    # if deposit is not recognized yet we get https://github.com/omisego/elixir-omg/issues/1128
    exit_data = pull_api_until_successful(InFlightExit, :in_flight_exit_get_data, Watcher.new(), payload)
    IfeExitData.to_struct(exit_data)
    %{ife | exit_data: IfeExitData.to_struct(exit_data)}
  end

  defp get_exit_game_contract_address(ife) do
    data = ABI.encode("exitGames(uint256)", [PaymentType.simple_payment_transaction()])
    {:ok, result} = Ethereumex.HttpClient.eth_call(%{to: Itest.Account.plasma_framework(), data: Encoding.to_hex(data)})

    exit_game_contract_address =
      result
      |> Encoding.to_binary()
      |> ABI.TypeDecoder.decode([:address])
      |> hd()
      |> Encoding.to_hex()

    %{ife | exit_game_contract_address: exit_game_contract_address}
  end

  defp add_exit_queue(%__MODULE__{} = ife) do
    if has_exit_queue?() do
      _ = Logger.info("Exit queue was already added.")
      ife
    else
      _ = Logger.info("Exit queue missing. Adding...")

      data =
        ABI.encode(
          "addExitQueue(uint256,address)",
          [Itest.Account.vault_id(Currency.ether()), Currency.ether()]
        )

      txmap = %{
        from: ife.address,
        to: Itest.Account.plasma_framework(),
        value: Encoding.to_hex(0),
        data: Encoding.to_hex(data),
        gas: Encoding.to_hex(@gas_add_exit_queue)
      }

      {:ok, receipt_hash} = Ethereumex.HttpClient.eth_send_transaction(txmap)
      wait_on_receipt_confirmed(receipt_hash)
      wait_for_exit_queue(ife, @retry_count)
      %{ife | add_exit_queue_hash: receipt_hash}
    end
  end

  defp get_in_flight_exit_bond_size(ife) do
    _ = Logger.info("Trying to get bond size for in flight exit.")
    data = ABI.encode("startIFEBondSize()", [])
    {:ok, result} = Ethereumex.HttpClient.eth_call(%{to: ife.exit_game_contract_address, data: Encoding.to_hex(data)})

    in_flight_exit_bond_size =
      result
      |> Encoding.to_binary()
      |> ABI.TypeDecoder.decode([{:uint, 128}])
      |> hd()

    %{ife | in_flight_exit_bond_size: in_flight_exit_bond_size}
  end

  # This takes all the data we get from the Watcher to start an in flight exit.
  # Since we get it as a hex string, we convert it back to binary so that we can
  # ABI encode the data and send it back to the contract to start the in flight exit.
  defp do_in_flight_exit(
         %{address: address, exit_data: exit_data, exit_game_contract_address: exit_game_contract_address} = ife
       ) do
    in_flight_tx = Encoding.to_binary(exit_data.in_flight_tx)
    in_flight_tx_sigs = Enum.map(exit_data.in_flight_tx_sigs, &Encoding.to_binary(&1))
    input_txs = Enum.map(exit_data.input_txs, &Encoding.to_binary(&1))
    input_txs_inclusion_proofs = Enum.map(exit_data.input_txs_inclusion_proofs, &Encoding.to_binary(&1))
    input_utxos_pos = Enum.map(exit_data.input_utxos_pos, &:binary.encode_unsigned(&1))

    values = [
      {in_flight_tx, input_txs, input_utxos_pos, input_txs_inclusion_proofs, in_flight_tx_sigs}
    ]

    data =
      ABI.encode(
        "startInFlightExit((bytes,bytes[],uint256[],bytes[],bytes[]))",
        values
      )

    txmap = %{
      from: address,
      to: exit_game_contract_address,
      value: Encoding.to_hex(ife.in_flight_exit_bond_size),
      data: Encoding.to_hex(data),
      gas: Encoding.to_hex(@ife_gas * 2),
      gasPrice: Encoding.to_hex(@ife_gas_price)
    }

    {:ok, receipt_hash} = Ethereumex.HttpClient.eth_send_transaction(txmap)
    _ = Logger.info("Done IFE with hash #{receipt_hash}")
    wait_on_receipt_confirmed(receipt_hash)

    %{ife | start_in_flight_exit: receipt_hash}
  end

  defp get_in_flight_exit_id(%__MODULE__{exit_data: exit_data} = ife) do
    _ = Logger.info("Get in flight exit id...")
    txbytes = Encoding.to_binary(exit_data["in_flight_tx"])
    data = ABI.encode("getInFlightExitId(bytes)", [txbytes])
    {:ok, result} = Ethereumex.HttpClient.eth_call(%{to: ife.exit_game_contract_address, data: Encoding.to_hex(data)})

    ife_exit_id =
      result
      |> Encoding.to_binary()
      |> ABI.TypeDecoder.decode([{:uint, 128}])
      |> hd()

    _ = Logger.warn("IFE id is #{ife_exit_id}")

    get_next_exit_from_queue()

    %{ife | ife_exit_id: ife_exit_id}
  end

  defp get_in_flight_exits(%__MODULE__{ife_exit_id: ife_exit_id} = ife) do
    _ = Logger.info("Get in flight exits...")
    data = ABI.encode("inFlightExits(uint160)", [ife_exit_id])
    {:ok, result} = Ethereumex.HttpClient.eth_call(%{to: ife.exit_game_contract_address, data: Encoding.to_hex(data)})

    return_struct = [
      :bool,
      {:uint, 64},
      {:uint, 256},
      {:uint, 256},
      # NOTE: there are these two more fields in the return but they can be ommitted,
      #       both have withdraw_data_struct type
      # withdraw_data_struct,
      # withdraw_data_struct,
      :address,
      {:uint, 256},
      {:uint, 256}
    ]

    # struct InFlightExit {
    #  bool isCanonical,
    #  uint64 exitStartTimestamp,
    #  uint256 exitMap,
    #  uint256 position,
    #  struct PaymentExitDataModel.WithdrawData[4] inputs,
    #  struct PaymentExitDataModel.WithdrawData[4] outputs,
    #  address payable bondOwner,
    #  uint256 bondSize,
    #  uint256 oldestCompetitorPosition
    # }

    ife_exit_ids =
      result
      |> Encoding.to_binary()
      |> ABI.TypeDecoder.decode(return_struct)

    _ = Logger.info("IFEs #{inspect(ife_exit_ids)}")
    %{ife | ife_exit_ids: ife_exit_ids}
  end

  defp get_piggyback_bond_size(%__MODULE__{exit_game_contract_address: exit_game_contract_address} = ife) do
    _ = Logger.info("Trying to get bond size for in flight exit.")
    data = ABI.encode("piggybackBondSize()", [])
    {:ok, result} = Ethereumex.HttpClient.eth_call(%{to: exit_game_contract_address, data: Encoding.to_hex(data)})

    piggyback_bond_size =
      result
      |> Encoding.to_binary()
      |> ABI.TypeDecoder.decode([{:uint, 128}])
      |> hd()

    %{ife | piggyback_bond_size: piggyback_bond_size}
  end

  defp piggyback_input(
         %{
           address: address,
           exit_data: exit_data,
           exit_game_contract_address: exit_game_contract_address
         } = ife
       ) do
    _ = Logger.info("Piggyback input...")

    in_flight_tx = Encoding.to_binary(exit_data["in_flight_tx"])

    data =
      ABI.encode(
        "piggybackInFlightExitOnInput((bytes,uint16))",
        [{in_flight_tx, 0}]
      )

    txmap = %{
      from: address,
      to: exit_game_contract_address,
      value: Encoding.to_hex(ife.piggyback_bond_size),
      data: Encoding.to_hex(data),
      gas: Encoding.to_hex(@gas_piggyback)
    }

    {:ok, receipt_hash} = Ethereumex.HttpClient.eth_send_transaction(txmap)
    wait_on_receipt_confirmed(receipt_hash)
    _ = Logger.info("Piggyback input... DONE.")
    %{ife | piggyback_input_hash: receipt_hash}
  end

  defp wait_for_exit_period(ife) do
    _ = Logger.info("Wait for exit period to pass.")
    data = ABI.encode("minExitPeriod()", [])
    {:ok, result} = Ethereumex.HttpClient.eth_call(%{to: Itest.Account.plasma_framework(), data: Encoding.to_hex(data)})
    # result is in seconds
    result
    |> Encoding.to_binary()
    |> ABI.TypeDecoder.decode([{:uint, 160}])
    |> hd()
    # to milliseconds
    |> Kernel.*(1000)
    # needs a be a tiny more than exit period seconds
    |> Kernel.+(1500)
    |> Process.sleep()

    ife
  end

  defp process_exit(%__MODULE__{address: address} = ife) do
    _ = Logger.info("Process exit #{__MODULE__}")

    data =
      ABI.encode(
        "processExits(uint256,address,uint160,uint256)",
        [Itest.Account.vault_id(Currency.ether()), Currency.ether(), ife.ife_exit_id, 1]
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
    wait_on_receipt_confirmed(receipt_hash)

    get_next_exit_from_queue()

    get_next_exit_from_queue()

    %{ife | process_exit_receipt_hash: receipt_hash}
  end

  ##
  ## helper functions
  ##
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

  defp get_next_exit_from_queue() do
    data = ABI.encode("getNextExit(uint256,address)", [Itest.Account.vault_id(Currency.ether()), Currency.ether()])
    {:ok, result} = Ethereumex.HttpClient.eth_call(%{to: Itest.Account.plasma_framework(), data: Encoding.to_hex(data)})

    case Encoding.to_binary(result) do
      "" ->
        _ = Logger.info("Empty exit queue while #{__MODULE__}.")

      result ->
        next_exit_id = hd(ABI.TypeDecoder.decode(result, [{:uint, 256}]))
        exit_id = next_exit_id &&& (1 <<< 160) - 1
        _ = Logger.warn("First exit id in the queue is #{exit_id}")
    end
  end
end

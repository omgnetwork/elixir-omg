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

  defstruct [
    :address,
    :address_key,
    :exit_data,
    :exit_game_contract_address,
    :receiver_address,
    :sign_hash,
    :signed_txbytes,
    :txbytes
  ]

  def start_in_flight_exit(sender_address, sender_key, receiver_address) do
    %__MODULE__{address: sender_address, address_key: sender_key, receiver_address: receiver_address}
    |> create_transaction()
    |> sign_transaction()
    |> get_exit_data()
    |> get_exit_game_contract_address()
    |> do_in_flight_exit()
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
    in_flight_tx = exit_data["in_flight_tx"]
    in_flight_tx_sigs = exit_data["in_flight_tx_sigs"]
    input_txs = exit_data["input_txs"]
    input_txs_inclusion_proofs = exit_data["input_txs_inclusion_proofs"]
    input_utxos_pos = exit_data["input_utxos_pos"]

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
end

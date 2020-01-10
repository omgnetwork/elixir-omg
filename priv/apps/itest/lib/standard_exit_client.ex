defmodule Itest.StandardExitClient do
  @moduledoc """
    An interface to Watcher API.
  """
  alias Itest.ApiModel.Utxo
  alias Itest.Transactions.Currency
  alias Itest.Transactions.Encoding
  alias Itest.Transactions.PaymentType
  alias WatcherInfoAPI.Connection, as: WatcherInfo
  alias WatcherInfoAPI.Model.AddressBodySchema1
  alias WatcherSecurityCriticalAPI.Connection, as: Watcher
  alias WatcherSecurityCriticalAPI.Model.UtxoPositionBodySchema1

  import Itest.Poller, only: [wait_on_receipt_confirmed: 1, pull_api_until_successful: 4]

  use Bitwise
  require Logger

  defstruct [
    :address,
    :utxo,
    :exit_data,
    :exit_game_contract_address,
    :standard_exit_bond_size,
    :standard_exit_id,
    :add_exit_queue_hash,
    :start_standard_exit_hash,
    :process_exit_receipt_hash,
    :total_gas_used
  ]

  @gas 540_000
  @gas_process_exit 5_712_388
  @gas_process_exit_price 1_000_000_000
  @gas_add_exit_queue 800_000

  @sleep_retry_sec 5_000
  @retry_count 120

  def start_standard_exit(address) do
    _ = Logger.info("Starting standard exit for #{address}")

    %__MODULE__{address: address}
    |> get_utxo()
    |> get_exit_data()
    |> get_exit_game_contract_address()
    |> add_exit_queue()
    |> get_bond_size_for_standard_exit()
    |> do_start_standard_exit()
    |> wait_for_exit_period()
    |> get_standard_exit_id()
    |> process_exit()
    |> calculate_total_gas_used()
  end

  # taking the first UTXO from the json array
  defp get_utxo(%__MODULE__{address: address} = se) do
    payload = %AddressBodySchema1{address: address}

    response =
      pull_api_until_successful(
        WatcherInfoAPI.Api.Account,
        :account_get_utxos,
        WatcherInfo.new(),
        payload
      )

    %{se | utxo: response |> hd |> Utxo.to_struct()}
  end

  defp get_exit_data(%__MODULE__{utxo: %Utxo{utxo_pos: utxo_pos}} = se) do
    payload = %UtxoPositionBodySchema1{utxo_pos: utxo_pos}

    response =
      pull_api_until_successful(WatcherSecurityCriticalAPI.Api.UTXO, :utxo_get_exit_data, Watcher.new(), payload)

    %{se | exit_data: Itest.ApiModel.ExitData.to_struct(response)}
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
<<<<<<< HEAD
      wait_on_receipt_confirmed(receipt_hash, @retry_count)
=======
      wait_on_receipt_confirmed(receipt_hash)
>>>>>>> feature: introduce cabbage
      wait_for_exit_queue(se, @retry_count)
      %{se | add_exit_queue_hash: receipt_hash}
    end
  end

  defp get_bond_size_for_standard_exit(%__MODULE__{exit_game_contract_address: exit_game_contract_address} = se) do
    _ = Logger.info("Trying to get bond size for standard exit.")
    data = ABI.encode("startStandardExitBondSize()", [])
    {:ok, result} = Ethereumex.HttpClient.eth_call(%{to: exit_game_contract_address, data: Encoding.to_hex(data)})

    standard_exit_bond_size =
      result
      |> Encoding.to_binary()
      |> ABI.TypeDecoder.decode([{:uint, 128}])
      |> hd()

    %{se | standard_exit_bond_size: standard_exit_bond_size}
  end

  defp do_start_standard_exit(
         %__MODULE__{
           standard_exit_bond_size: standard_exit_bond_size,
           address: address,
           exit_game_contract_address: exit_game_contract_address,
           exit_data: exit_data
         } = se
       ) do
    _ = Logger.info("Starting standard exit.")

    data =
      ABI.encode("startStandardExit((uint256,bytes,bytes))", [
        {exit_data.utxo_pos, Encoding.to_binary(exit_data.txbytes), Encoding.to_binary(exit_data.proof)}
      ])

    txmap = %{
      from: address,
      to: exit_game_contract_address,
      value: Encoding.to_hex(standard_exit_bond_size),
      data: Encoding.to_hex(data),
      gas: Encoding.to_hex(@gas)
    }

    {:ok, receipt_hash} = Ethereumex.HttpClient.eth_send_transaction(txmap)
    wait_on_receipt_confirmed(receipt_hash)
    %{se | start_standard_exit_hash: receipt_hash}
  end

  defp wait_for_exit_period(se) do
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
    |> Kernel.+(500)
    |> Process.sleep()

    se
  end

  defp get_standard_exit_id(
         %__MODULE__{exit_game_contract_address: exit_game_contract_address, exit_data: exit_data} = se
       ) do
    data =
      ABI.encode("getStandardExitId(bool,bytes,uint256)", [
        true,
        Encoding.to_binary(exit_data.txbytes),
        exit_data.utxo_pos
      ])

    {:ok, result} = Ethereumex.HttpClient.eth_call(%{to: exit_game_contract_address, data: Encoding.to_hex(data)})

    standard_exit_id =
      result
      |> Encoding.to_binary()
      |> ABI.TypeDecoder.decode([{:uint, 160}])
      |> hd()

    data = ABI.encode("getNextExit(uint256,address)", [Itest.Account.vault_id(Currency.ether()), Currency.ether()])
    {:ok, result} = Ethereumex.HttpClient.eth_call(%{to: Itest.Account.plasma_framework(), data: Encoding.to_hex(data)})

    next_exit_id =
      result
      |> Encoding.to_binary()
      |> ABI.TypeDecoder.decode([{:uint, 256}])
      |> hd()

    # double check correctness, our exit ID must be the first one in the priority queue
    ^standard_exit_id = next_exit_id &&& (1 <<< 160) - 1

    %{se | standard_exit_id: standard_exit_id}
  end

  defp process_exit(%__MODULE__{address: address} = se) do
    _ = Logger.info("Process exit #{__MODULE__}")

    data =
      ABI.encode(
        "processExits(uint256,address,uint160,uint256)",
        [Itest.Account.vault_id(Currency.ether()), Currency.ether(), se.standard_exit_id, 1]
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

    %{se | process_exit_receipt_hash: receipt_hash}
  end

  defp calculate_total_gas_used(
         %__MODULE__{
           add_exit_queue_hash: add_exit_queue_hash,
           process_exit_receipt_hash: process_exit_receipt_hash,
           start_standard_exit_hash: start_standard_exit_hash
         } = se
       ) do
    _ = Logger.info("Calculating total gas used.")
    receipt_hashes = [add_exit_queue_hash, process_exit_receipt_hash, start_standard_exit_hash]

    total_gas_used =
      Enum.reduce(receipt_hashes, 0, fn receipt_hash, acc ->
        gas = Itest.Gas.get_gas_used(receipt_hash)
        acc + gas
      end)

    _ = Logger.info("Calculating total gas used done. Result #{total_gas_used}.")
    %{se | total_gas_used: total_gas_used}
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

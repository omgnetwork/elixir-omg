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

defmodule LoadTest.Ethereum do
  @moduledoc """
  Support for synchronous transactions.
  """
  require Logger

  alias ExPlasma.Encoding
  alias LoadTest.ChildChain.Abi
  alias LoadTest.Ethereum.NonceTracker
  alias LoadTest.Ethereum.Sync
  alias LoadTest.Ethereum.Transaction
  alias LoadTest.Ethereum.Transaction.Signature

  @about_4_blocks_time 120_000

  @type hash_t() :: <<_::256>>

  @doc """
  Send transaction to be singed by a key managed by Ethereum node, geth or parity.
  For geth, account must be unlocked externally.
  If using parity, account passphrase must be provided directly or via config.
  """
  @spec contract_transact(<<_::160>>, <<_::160>>, binary, [any]) :: {:ok, <<_::256>>} | {:error, any}
  def contract_transact(from, to, signature, args, opts \\ []) do
    data = encode_tx_data(signature, args)

    txmap =
      %{from: Encoding.to_hex(from), to: Encoding.to_hex(to), data: data}
      |> Map.merge(Map.new(opts))
      |> encode_all_integer_opts()

    case Ethereumex.HttpClient.eth_send_transaction(txmap) do
      {:ok, receipt_enc} -> {:ok, Encoding.to_binary(receipt_enc)}
      other -> other
    end
  end

  @spec get_gas_used(String.t()) :: non_neg_integer()
  def get_gas_used(receipt_hash) do
    result =
      {Ethereumex.HttpClient.eth_get_transaction_receipt(receipt_hash),
       Ethereumex.HttpClient.eth_get_transaction_by_hash(receipt_hash)}

    case result do
      {{:ok, %{"gasUsed" => gas_used}}, {:ok, %{"gasPrice" => gas_price}}} ->
        {gas_price_value, ""} = gas_price |> String.replace_prefix("0x", "") |> Integer.parse(16)
        {gas_used_value, ""} = gas_used |> String.replace_prefix("0x", "") |> Integer.parse(16)
        gas_price_value * gas_used_value

      {{:ok, nil}, {:ok, nil}} ->
        0
    end
  end

  @doc """
  Waits until transaction is mined
  Returns transaction receipt updated with Ethereum block number in which the transaction was mined
  """
  @spec transact_sync(hash_t(), pos_integer()) :: {:ok, map()}
  def transact_sync(txhash, timeout \\ @about_4_blocks_time) do
    {:ok, %{"status" => "0x1"} = receipt} = eth_receipt(txhash, timeout)
    {:ok, Map.update!(receipt, "blockNumber", &Encoding.to_int(&1))}
  end

  def block_hash(mined_num) do
    contract_address = Application.fetch_env!(:load_test, :contract_address_plasma_framework)

    %{"block_hash" => block_hash, "block_timestamp" => block_timestamp} =
      get_external_data(contract_address, "blocks(uint256)", [mined_num])

    {block_hash, block_timestamp}
  end

  def send_raw_transaction(txmap, sender) do
    nonce = NonceTracker.get_next_nonce(sender.addr)

    txmap
    |> Map.merge(%{nonce: nonce})
    |> Signature.sign_transaction(sender.priv)
    |> Transaction.serialize()
    |> ExRLP.encode()
    |> Encoding.to_hex()
    |> Ethereumex.HttpClient.eth_send_raw_transaction()
  end

  def get_next_nonce_for_account(address) when byte_size(address) == 20 do
    address
    |> ExPlasma.Encoding.to_hex()
    |> get_next_nonce_for_account()
  end

  def get_next_nonce_for_account("0x" <> _ = address) do
    {:ok, nonce} = Ethereumex.HttpClient.eth_get_transaction_count(address)
    Encoding.to_int(nonce)
  end

  def wait_for_root_chain_block(awaited_eth_height, timeout \\ 600_000) do
    f = fn ->
      {:ok, eth_height} =
        case Ethereumex.HttpClient.eth_block_number() do
          {:ok, height_hex} ->
            {:ok, Encoding.to_int(height_hex)}

          other ->
            other
        end

      if eth_height < awaited_eth_height, do: :repeat, else: {:ok, eth_height}
    end

    Sync.repeat_until_success(f, timeout)
  end

  def fetch_balance(address, amount, currency \\ <<0::160>>) do
    fetch_balance(Encoding.to_hex(address), amount, Encoding.to_hex(currency), 60)
  end

  def fetch_rootchain_balance(address, <<0::160>>) do
    root_chain_get_eth_balance(Encoding.to_hex(address), 10)
  end

  def fetch_rootchain_balance(address, currency) do
    root_chain_get_erc20_balance(Encoding.to_hex(address), Encoding.to_hex(currency), 10)
  end

  def create_transaction(amount_in_wei, input_address, output_address, currency \\ <<0::160>>, tries \\ 120) do
    transaction = %WatcherInfoAPI.Model.CreateTransactionsBodySchema{
      owner: Encoding.to_hex(input_address),
      payments: [
        %WatcherInfoAPI.Model.TransactionCreatePayments{
          amount: amount_in_wei,
          currency: Encoding.to_hex(currency),
          owner: Encoding.to_hex(output_address)
        }
      ],
      fee: %WatcherInfoAPI.Model.TransactionCreateFee{currency: Encoding.to_hex(currency)}
    }

    {:ok, response} =
      WatcherInfoAPI.Api.Transaction.create_transaction(LoadTest.Connection.WatcherInfo.client(), transaction)

    result = Jason.decode!(response.body)["data"]
    process_transaction_result(result, amount_in_wei, input_address, output_address, currency, tries)
  end

  def submit_transaction(typed_data, sign_hash, private_keys) do
    signatures =
      Enum.map(private_keys, fn private_key ->
        sign_hash
        |> to_binary()
        |> signature_digest(private_key)
        |> Encoding.to_hex()
      end)

    typed_data_signed = Map.put_new(typed_data, "signatures", signatures)

    submit_typed(typed_data_signed)
  end

  defp to_binary(hex) do
    hex
    |> String.replace_prefix("0x", "")
    |> String.upcase()
    |> Base.decode16!()
  end

  defp signature_digest(hash_digest, private_key_binary) do
    {:ok, <<r::size(256), s::size(256)>>, recovery_id} =
      :libsecp256k1.ecdsa_sign_compact(
        hash_digest,
        private_key_binary,
        :default,
        <<>>
      )

    # EIP-155
    # See https://github.com/ethereum/EIPs/blob/master/EIPS/eip-155.md
    base_recovery_id = 27
    recovery_id = base_recovery_id + recovery_id

    <<r::integer-size(256), s::integer-size(256), recovery_id::integer-size(8)>>
  end

  defp submit_typed(typed_data_signed, retry_count \\ 120)

  defp submit_typed(typed_data_signed, 0), do: execute_submit_typed(typed_data_signed)

  defp submit_typed(typed_data_signed, counter) do
    {:ok, response} = execute_submit_typed(typed_data_signed)
    decoded_response = Jason.decode!(response.body)["data"]

    case decoded_response do
      %{"messages" => %{"code" => "submit:utxo_not_found"}} ->
        Process.sleep(1_000)
        submit_typed(typed_data_signed, counter - 1)

      %{"messages" => %{"code" => "operation:service_unavailable"}} ->
        Process.sleep(1_000)
        submit_typed(typed_data_signed, counter - 1)

      %{"txhash" => _} ->
        decoded_response
    end
  end

  defp execute_submit_typed(typed_data_signed) do
    WatcherInfoAPI.Api.Transaction.submit_typed(LoadTest.Connection.WatcherInfo.client(), typed_data_signed)
  end

  defp process_transaction_result(
         result,
         amount_in_wei,
         input_address,
         output_address,
         currency,
         tries
       ) do
    case {result, tries} do
      {%{"code" => "create:client_error", "messages" => %{"code" => "operation:service_unavailable"}}, 0} ->
        {:error, result}

      {%{
         "result" => "complete",
         "transactions" => [
           %{
             "sign_hash" => sign_hash,
             "typed_data" => typed_data,
             "txbytes" => txbytes
           }
         ]
       }, _} ->
        {:ok, [sign_hash, typed_data, txbytes]}

      _ ->
        Process.sleep(1_000)
        create_transaction(amount_in_wei, input_address, output_address, currency, tries - 1)
    end
  end

  defp root_chain_get_eth_balance(address, 0) do
    {:ok, initial_balance} = eth_account_get_balance(address)
    {initial_balance, ""} = initial_balance |> String.replace_prefix("0x", "") |> Integer.parse(16)
    initial_balance
  end

  defp root_chain_get_eth_balance(address, counter) do
    response = eth_account_get_balance(address)

    case response do
      {:ok, initial_balance} ->
        {initial_balance, ""} = initial_balance |> String.replace_prefix("0x", "") |> Integer.parse(16)
        initial_balance

      _ ->
        Process.sleep(1_000)
        root_chain_get_eth_balance(address, counter - 1)
    end
  end

  defp eth_account_get_balance(address) do
    Ethereumex.HttpClient.eth_get_balance(address)
  end

  defp root_chain_get_erc20_balance(address, currency, 0) do
    do_root_chain_get_erc20_balance(address, currency)
  end

  defp root_chain_get_erc20_balance(address, currency, counter) do
    case do_root_chain_get_erc20_balance(address, currency) do
      {:ok, balance} ->
        balance

      _ ->
        Process.sleep(1_000)
        root_chain_get_erc20_balance(address, currency, counter - 1)
    end
  end

  defp do_root_chain_get_erc20_balance(address, currency) do
    data = ABI.encode("balanceOf(address)", [Encoding.to_binary(address)])

    case Ethereumex.HttpClient.eth_call(%{to: Encoding.to_hex(currency), data: Encoding.to_hex(data)}) do
      {:ok, result} ->
        balance =
          result
          |> Encoding.to_binary()
          |> ABI.TypeDecoder.decode([{:uint, 256}])
          |> hd()

        {:ok, balance}

      error ->
        error
    end
  end

  defp fetch_balance(address, amount, currency, counter) do
    response =
      case account_get_balances(address) do
        {:ok, response} ->
          decoded_response = Jason.decode!(response.body)
          Enum.find(decoded_response["data"], fn data -> data["currency"] == currency end)

        _ ->
          # socket closed etc.
          :error
      end

    case response do
      # empty response is considered no account balance!
      nil when amount == 0 ->
        nil

      %{"amount" => ^amount} = balance ->
        balance

      error ->
        if counter == 0 do
          error
        else
          Process.sleep(1_000)

          fetch_balance(address, amount, currency, counter - 1)
        end
    end
  end

  defp account_get_balances(address) do
    WatcherInfoAPI.Api.Account.account_get_balance(
      LoadTest.Connection.WatcherInfo.client(),
      %{
        address: address
      }
    )
  end

  defp get_external_data(address, signature, params) do
    data = signature |> ABI.encode(params) |> Encoding.to_hex()

    {:ok, data} = Ethereumex.HttpClient.eth_call(%{to: address, data: data})

    Abi.decode_function(data, signature)
  end

  defp eth_receipt(txhash, timeout) do
    f = fn ->
      txhash
      |> Ethereumex.HttpClient.eth_get_transaction_receipt()
      |> case do
        {:ok, receipt} when receipt != nil -> {:ok, receipt}
        _ -> :repeat
      end
    end

    Sync.repeat_until_success(f, timeout)
  end

  defp encode_tx_data(signature, args) do
    signature
    |> ABI.encode(args)
    |> Encoding.to_hex()
  end

  defp encode_all_integer_opts(opts) do
    opts
    |> Enum.filter(fn {_k, v} -> is_integer(v) end)
    |> Enum.into(opts, fn {k, v} -> {k, Encoding.to_hex(v)} end)
  end
end

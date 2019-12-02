defmodule Itest.Client do
  @moduledoc """
    An interface to Watcher API.
  """
  alias Itest.ApiModel.Utxo

  alias Itest.Transactions.Currency
  alias Itest.Transactions.Deposit
  alias Itest.Transactions.Encoding

  alias WatcherSecurityCriticalAPI.Connection, as: Watcher

  alias Itest.ApiModel.SubmitTransactionResponse

  alias WatchersInformationalAPI.Api.Account
  alias WatchersInformationalAPI.Api.Transaction

  alias WatchersInformationalAPI.Model.AddressBodySchema1
  alias WatchersInformationalAPI.Model.CreateTransactionsBodySchema
  alias WatchersInformationalAPI.Model.TransactionCreateFee
  alias WatchersInformationalAPI.Model.TransactionCreatePayments

  import Itest.Poller, only: [wait_on_receipt_confirmed: 2]

  require Logger

  @gas 180_000

  @sleep_retry_sec 1_000
  @retry_count 60

  def deposit(amount_in_wei, output_address, vault_address, currency \\ Currency.ether()) do
    deposit_transaction = deposit_transaction(amount_in_wei, output_address, currency)

    data = ABI.encode("deposit(bytes)", [deposit_transaction])

    txmap = %{
      from: output_address,
      to: vault_address,
      value: Encoding.to_hex(amount_in_wei),
      data: Encoding.to_hex(data),
      gas: Encoding.to_hex(@gas)
    }

    {:ok, receipt_hash} = Ethereumex.HttpClient.eth_send_transaction(txmap)

    wait_on_receipt_confirmed(receipt_hash, @retry_count)
    {:ok, receipt_hash}
  end

  def create_transaction(amount_in_wei, input_address, output_address, currency \\ Currency.ether()) do
    transaction = %CreateTransactionsBodySchema{
      owner: input_address,
      payments: [
        %TransactionCreatePayments{
          amount: amount_in_wei,
          currency: Encoding.to_hex(currency),
          owner: output_address
        }
      ],
      fee: %TransactionCreateFee{amount: 0, currency: Encoding.to_hex(currency)}
    }

    {:ok, response} = Transaction.create_transaction(Watcher.new(), transaction)

    %{
      "result" => "complete",
      "transactions" => [
        %{
          "sign_hash" => sign_hash,
          "typed_data" => typed_data
        }
      ]
    } = Jason.decode!(response.body)["data"]

    {:ok, [sign_hash, typed_data]}
  end

  def submit_transaction(typed_data, sign_hash, private_key) do
    signature =
      sign_hash
      |> Encoding.to_binary()
      |> Encoding.signature_digest(private_key)

    typed_data_signed = Map.put_new(typed_data, "signatures", [Encoding.to_hex(signature)])

    submit_typed(typed_data_signed)
  end

  def get_balance(address), do: get_balance(address, @retry_count)

  def get_balance(address, 0) do
    {:ok, response} = account_get_balance(address)
    Jason.decode!(response.body)["data"]
  end

  def get_balance(address, counter) do
    {:ok, response} = account_get_balance(address)

    decoded_response = Jason.decode!(response.body)

    case decoded_response["data"] do
      [] ->
        Process.sleep(@sleep_retry_sec)
        get_balance(address, counter - 1)

      [data] ->
        data
    end
  end

  def get_utxos(address) do
    payload = %AddressBodySchema1{address: address}
    {:ok, response} = Account.account_get_utxos(Watcher.new(), payload)
    Poison.decode!(response.body, as: %{"data" => [%Utxo{}]})["data"]
  end

  def get_gas_used(receipt_hash), do: Itest.Gas.get_gas_used(receipt_hash)

  defp account_get_balance(address) do
    Account.account_get_balance(
      Watcher.new(),
      %{
        address: address
      }
    )
  end

  defp deposit_transaction(amount_in_wei, address, currency) do
    address
    |> Deposit.new(currency, amount_in_wei)
    |> Encoding.get_data_for_rlp()
    |> ExRLP.encode()
  end

  defp submit_typed(typed_data_signed), do: submit_typed(typed_data_signed, @retry_count)
  defp submit_typed(typed_data_signed, 0), do: do_submit_typed(typed_data_signed)

  defp submit_typed(typed_data_signed, counter) do
    {:ok, response} = do_submit_typed(typed_data_signed)
    decoded_response = Jason.decode!(response.body)["data"]

    case decoded_response do
      %{"messages" => %{"code" => "submit:utxo_not_found"}} ->
        Process.sleep(@sleep_retry_sec)
        submit_typed(typed_data_signed, counter - 1)

      %{"txhash" => _} ->
        struct(SubmitTransactionResponse, decoded_response)
    end
  end

  defp do_submit_typed(typed_data_signed) do
    Transaction.submit_typed(Watcher.new(), typed_data_signed)
  end
end

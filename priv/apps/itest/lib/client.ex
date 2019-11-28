defmodule Itest.Client do
  @moduledoc """
    An interface to Watcher API.
  """
  alias Itest.ApiModel.Utxo
  alias Itest.Transactions.Currency
  alias Itest.Transactions.Deposit
  alias Itest.Transactions.Encoding
  alias WatchersInformationalAPI.Connection, as: WatcherInformational
  alias WatchersInformationalAPI.Api.Account
  alias WatchersInformationalAPI.Api.Transaction
  alias WatchersInformationalAPI.Model.AddressBodySchema1
  alias WatchersInformationalAPI.Model.CreateTransactionsBodySchema
  alias WatchersInformationalAPI.Model.TransactionCreateFee
  alias WatchersInformationalAPI.Model.TransactionCreatePayments

  import Itest.Poller, only: [wait_on_receipt_confirmed: 2, submit_typed: 1]

  require Logger

  @gas 180_000
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

    {:ok, response} = Transaction.create_transaction(WatcherInformational.new(), transaction)

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

  def get_utxos(address) do
    payload = %AddressBodySchema1{address: address}
    {:ok, response} = Account.account_get_utxos(WatcherInformational.new(), payload)
    Poison.decode!(response.body, as: %{"data" => [%Utxo{}]})["data"]
  end

  def get_gas_used(receipt_hash), do: Itest.Gas.get_gas_used(receipt_hash)

  def get_balance(address), do: Itest.Poller.get_balance(address)
  def get_balance(address, amount), do: Itest.Poller.pull_balance_until_amount(address, amount)

  def eth_get_balance(address), do: Itest.Poller.eth_get_balance(address)

  defp deposit_transaction(amount_in_wei, address, currency) do
    address
    |> Deposit.new(currency, amount_in_wei)
    |> Encoding.get_data_for_rlp()
    |> ExRLP.encode()
  end
end

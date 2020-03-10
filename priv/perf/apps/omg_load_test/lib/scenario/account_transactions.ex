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

defmodule OMG.LoadTest.Scenario.AccountTransactions do
  @moduledoc """
  This scenario tests watcher info apis when number of transaction increases for an account.
  """

  use Chaperon.Scenario

  alias Chaperon.Timing

  alias OMG.LoadTest.Utils.Encoding
  alias OMG.LoadTest.Utils.Generators
  alias OMG.LoadTest.Connection.WatcherInfo, as: Connection
  alias WatcherInfoAPI.Api
  alias WatcherInfoAPI.Model

  @poll_interval 1_000

  @eth <<0::160>>

  @spec init(Chaperon.Session.t()) :: Chaperon.Session.t()
  def init(session) do
    session
    |> log_info("start init with random delay...")
    |> random_delay(Timing.seconds(5))
  end

  def run(session) do
    iterations = config(session, [:iterations])

    {:ok, [{sender, _sender_utxo} | _]} = Generators.generate_users(1)

    :ok = wait_for_balance_update(sender)

    session = log_info(session, "user created: " <> Encoding.to_hex(sender.addr))

    session
    |> repeat(:test_apis, [sender], iterations)
    |> log_info("end...")
  end

  def test_apis(session, sender) do
    session
    |> test_api_account_get_balance(sender)
    |> test_api_account_get_utxos(sender)
    |> test_api_account_get_transactions(sender)
    |> test_api_account_create_transactions(sender)
  end

  defp test_api_account_get_balance(session, sender) do
    start = Timing.timestamp()
    {:ok, _} = get_balance(sender)

    add_metric(
      session,
      {:call, {OMG.LoadTest.Scenario.AccountTransactions, '/account.get_balance'}},
      Timing.timestamp() - start
    )
  end

  defp test_api_account_get_utxos(session, sender) do
    start = Timing.timestamp()
    {:ok, _} = get_utxos(sender)

    add_metric(
      session,
      {:call, {OMG.LoadTest.Scenario.AccountTransactions, '/account.get_utxos'}},
      Timing.timestamp() - start
    )
  end

  defp test_api_account_get_transactions(session, sender) do
    start = Timing.timestamp()
    {:ok, _} = get_transactions(sender)

    add_metric(
      session,
      {:call, {OMG.LoadTest.Scenario.AccountTransactions, '/account.get_transactions'}},
      Timing.timestamp() - start
    )
  end

  defp test_api_account_create_transactions(session, sender) do
    start = Timing.timestamp()
    {:ok, [sign_hash, typed_data, _txbytes]} = create_transaction(sender)

    session =
      add_metric(
        session,
        {:call, {OMG.LoadTest.Scenario.AccountTransactions, '/transaction.create'}},
        Timing.timestamp() - start
      )

    typed_data_signed = sign_tx(sign_hash, typed_data, sender)

    start = Timing.timestamp()
    {:ok, response} = Api.Transaction.submit_typed(Connection.client(), typed_data_signed)

    session =
      add_metric(
        session,
        {:call, {OMG.LoadTest.Scenario.AccountTransactions, '/transaction.submit_typed'}},
        Timing.timestamp() - start
      )

    %{
      "txhash" => tx_id
    } = Jason.decode!(response.body)["data"]

    wait_until_tx_sync_to_watcher(tx_id)
    session
  end

  defp wait_for_balance_update(sender) do
    wait_for_balance_update(sender, 0)
  end

  defp wait_for_balance_update(_sender, 30), do: :timeout

  defp wait_for_balance_update(sender, poll_count) do
    {:ok, response_body} = get_balance(sender)
    utxos = Jason.decode!(response_body)["data"]

    if Enum.count(utxos) > 0 do
      :ok
    else
      Process.sleep(@poll_interval)
      wait_for_balance_update(sender, poll_count + 1)
    end
  end

  defp create_transaction(sender) do
    {:ok, response} =
      Api.Transaction.create_transaction(
        Connection.client(),
        %Model.CreateTransactionsBodySchema{
          owner: Encoding.to_hex(sender.addr),
          fee: %Model.TransactionCreateFee{
            currency: Encoding.to_hex(@eth)
          },
          payments: [
            %Model.TransactionCreatePayments{
              amount: 1,
              currency: Encoding.to_hex(@eth),
              owner: Encoding.to_hex(sender.addr)
            }
          ]
        }
      )

    %{
      "result" => "complete",
      "transactions" => [
        %{
          "sign_hash" => sign_hash,
          "typed_data" => typed_data,
          "txbytes" => txbytes
        }
      ]
    } = Jason.decode!(response.body)["data"]

    {:ok, [sign_hash, typed_data, txbytes]}
  end

  defp get_balance(sender) do
    {:ok, response} =
      Api.Account.account_get_balance(
        Connection.client(),
        %Model.AddressBodySchema{
          address: Encoding.to_hex(sender.addr)
        }
      )

    {:ok, response.body}
  end

  defp get_utxos(sender) do
    {:ok, response} =
      Api.Account.account_get_utxos(
        Connection.client(),
        %Model.AddressBodySchema1{
          address: Encoding.to_hex(sender.addr)
        }
      )

    {:ok, response.body}
  end

  defp get_transactions(sender) do
    {:ok, response} =
      Api.Account.account_get_transactions(
        Connection.client(),
        %Model.GetAllTransactionsBodySchema{}
      )

    {:ok, response.body}
  end

  defp sign_tx(sign_hash, typed_data, sender) do
    signature =
      sign_hash
      |> Encoding.to_binary()
      |> Encoding.signature_digest(Encoding.to_hex(sender.priv))
      |> Encoding.to_hex()

    typed_data_signed = Map.put_new(typed_data, "signatures", [signature])
    typed_data_signed
  end

  defp wait_until_tx_sync_to_watcher(tx_id) do
    {:ok, response} =
      Api.Transaction.transaction_get(
        Connection.client(),
        %Model.GetTransactionBodySchema{
          id: tx_id
        }
      )

    case Jason.decode!(response.body)["success"] do
      false ->
        Process.sleep(@poll_interval)
        wait_until_tx_sync_to_watcher(tx_id)

      true ->
        {:ok, response.body}
    end
  end
end

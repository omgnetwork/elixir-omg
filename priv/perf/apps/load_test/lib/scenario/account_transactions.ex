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

defmodule LoadTest.Scenario.AccountTransactions do
  @moduledoc """
  This scenario tests watcher info apis when number of transaction increases for an account.
  """

  use Chaperon.Scenario

  alias Chaperon.Timing
  alias LoadTest.Connection.WatcherInfo, as: Connection
  alias LoadTest.Service.Faucet
  alias LoadTest.Ethereum.Account
  alias LoadTest.Ethereum.Hash
  alias LoadTest.Utils.Encoding
  alias WatcherInfoAPI.Api
  alias WatcherInfoAPI.Model

  @poll_interval 15_000
  @default_retry_attempts 15

  @eth <<0::160>>
  @test_output_amount 1

  @spec init(Chaperon.Session.t()) :: Chaperon.Session.t()
  def init(session) do
    session
    |> log_info("start init with random delay...")
    |> random_delay(Timing.seconds(5))
  end

  def run(session) do
    iterations = config(session, [:iterations])
    fee_wei = Application.fetch_env!(:load_test, :fee_wei)

    amount = iterations * (@test_output_amount + fee_wei)
    {:ok, sender} = Account.new()
    {:ok, _} = Faucet.fund_child_chain_account(sender, amount, @eth)

    {:ok, faucet} = Faucet.get_faucet()

    session
    |> assign(faucet: faucet, iteration: 1)
    |> wait_for_balance_update(sender)
    |> log_info("user created: " <> Encoding.to_hex(sender.addr))
    |> repeat(:repeat_task, [sender], iterations)
    |> log_info("end...")
  end

  def wait_for_balance_update(session, sender, retry \\ @default_retry_attempts) do
    {:ok, session} = do_wait_for_balance_update(session, sender, retry)
    session
  end

  def repeat_task(session, sender) do
    session
    |> log_info("running iteration: " <> Integer.to_string(session.assigned.iteration))
    |> retry_on_error(:test_apis, [sender], retries: @default_retry_attempts, random_delay: seconds(30))
    |> update_assign(iteration: &(&1 + 1))
  end

  def test_apis(session, sender) do
    session
    |> test_api_account_get_balance(sender)
    |> test_api_account_get_utxos(sender)
    |> test_api_account_get_transactions(sender)
    |> test_api_account_create_and_submit_transactions(sender)
  end

  defp test_api_account_get_balance(session, sender) do
    start = Timing.timestamp()
    {:ok, _} = get_balance(sender)

    add_metric(
      session,
      {:call, {LoadTest.Scenario.AccountTransactions, '/account.get_balance'}},
      Timing.timestamp() - start
    )
  end

  defp test_api_account_get_utxos(session, sender) do
    start = Timing.timestamp()
    {:ok, _} = get_utxos(sender)

    add_metric(
      session,
      {:call, {LoadTest.Scenario.AccountTransactions, '/account.get_utxos'}},
      Timing.timestamp() - start
    )
  end

  defp test_api_account_get_transactions(session, sender) do
    start = Timing.timestamp()
    {:ok, _} = get_transactions(sender)

    add_metric(
      session,
      {:call, {LoadTest.Scenario.AccountTransactions, '/account.get_transactions'}},
      Timing.timestamp() - start
    )
  end

  defp test_api_account_create_and_submit_transactions(session, sender) do
    start = Timing.timestamp()
    {:ok, [inputs, sign_hash, typed_data, _txbytes]} = create_transaction(session, sender)

    session =
      add_metric(
        session,
        {:call, {LoadTest.Scenario.AccountTransactions, '/transaction.create'}},
        Timing.timestamp() - start
      )

    typed_data_signed = sign_tx(inputs, sign_hash, typed_data, sender)

    start = Timing.timestamp()
    {:ok, response} = Api.Transaction.submit_typed(Connection.client(), typed_data_signed)

    session =
      add_metric(
        session,
        {:call, {LoadTest.Scenario.AccountTransactions, '/transaction.submit_typed'}},
        Timing.timestamp() - start
      )

    %{
      "txhash" => tx_id
    } = Jason.decode!(response.body)["data"]

    wait_until_tx_sync_to_watcher(session, tx_id)
  end

  defp create_transaction(session, sender) do
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
              amount: @test_output_amount,
              currency: Encoding.to_hex(@eth),
              owner: Encoding.to_hex(session.assigned.faucet.addr)
            }
          ]
        }
      )

    %{
      "result" => "complete",
      "transactions" => [
        %{
          "inputs" => inputs,
          "sign_hash" => sign_hash,
          "typed_data" => typed_data,
          "txbytes" => txbytes
        }
      ]
    } = Jason.decode!(response.body)["data"]

    {:ok, [inputs, sign_hash, typed_data, txbytes]}
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

  defp get_transactions(_sender) do
    # There is an issue openapi generated client does not work well with optional request body
    # https://github.com/OpenAPITools/openapi-generator/issues/5234
    # So we are not filtering by sender now

    {:ok, response} =
      Api.Account.account_get_transactions(
        Connection.client(),
        %Model.GetAllTransactionsBodySchema{}
      )

    {:ok, response.body}
  end

  defp sign_tx(inputs, sign_hash, typed_data, sender) do
    signature =
      sign_hash
      |> Encoding.to_binary()
      |> Hash.sign_hash(sender.priv)
      |> Hash.pack_signature()
      |> Encoding.to_hex()

    signatures = Enum.map(inputs, fn _ -> signature end)
    Map.put_new(typed_data, "signatures", signatures)
  end

  defp do_wait_for_balance_update(_session, _sender, 0), do: :wait_for_balance_failed

  defp do_wait_for_balance_update(session, sender, retry) do
    {:ok, response_body} = get_balance(sender)
    utxos = Jason.decode!(response_body)["data"]

    if Enum.empty?(utxos) do
      Process.sleep(@poll_interval)

      session
      |> log_debug("retry for the balance update for sender: #{Encoding.to_hex(sender.addr)}")
      |> do_wait_for_balance_update(sender, retry - 1)
    else
      {:ok, session}
    end
  end

  defp wait_until_tx_sync_to_watcher(session, tx_id) do
    {:ok, session} = do_wait_until_tx_sync_to_watcher(session, tx_id, @default_retry_attempts)
    session
  end

  defp do_wait_until_tx_sync_to_watcher(_session, _tx_id, 0), do: :wait_until_tx_sync_failed

  defp do_wait_until_tx_sync_to_watcher(session, tx_id, retry) do
    {:ok, response} =
      Api.Transaction.transaction_get(
        Connection.client(),
        %Model.GetTransactionBodySchema{
          id: tx_id
        }
      )

    if Jason.decode!(response.body)["success"] do
      {:ok, session}
    else
      Process.sleep(@poll_interval)

      session
      |> log_debug("retry for watcher info to sync the submitted tx_id: #{tx_id}")
      |> do_wait_until_tx_sync_to_watcher(tx_id, retry - 1)
    end
  end
end

# Copyright 2018 OmiseGO Pte Ltd
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

defmodule OMG.Watcher.Web.Controller.Transaction do
  @moduledoc """
  Operations related to transaction.
  """

  use OMG.Watcher.Web, :controller
  use PhoenixSwagger

  alias OMG.API.State
  alias OMG.Watcher.API.Transaction
  alias OMG.Watcher.DB
  alias OMG.Watcher.Web.View

  import OMG.Watcher.Web.ErrorHandler

  @default_transactions_limit 200

  action_fallback(OMG.Watcher.Web.Controller.Fallback)

  @doc """
  Retrieves a specific transaction by id.
  """
  def get_transaction(conn, params) do
    with {:ok, id} <- Map.fetch(params, "id"),
         id <- Base.decode16!(id) do
      id
      |> Transaction.get()
      |> respond(conn)
    end
  end

  @doc """
  Retrieves a list of transactions
  """
  def get_transactions(conn, params) do
    address = Map.get(params, "address")
    limit = Map.get(params, "limit", @default_transactions_limit)
    {limit, ""} = limit |> Kernel.to_string() |> Integer.parse()
    # TODO: implement pagination. Defend against fetching huge dataset.
    limit = min(limit, @default_transactions_limit)
    transactions = Transaction.get_transactions(address, limit)

    respond_multiple(transactions, conn)
  end

  @doc """
  Produces hex-encoded transaction bytes for provided inputs and outputs.

  This is a convenience endpoint used by wallets. User's utxos and new outputs are provided to the endpoint.
  The endpoint responds with transaction bytes that wallet uses to sign with user's keys. Then signed transaction
  is submitted directly to plasma chain.
  """
  def transaction_encode(conn, params) do
    with {:ok, {inputs, outputs}} <- parse_params(params),
         {:ok, transaction} <- Transaction.create_from_utxos(inputs, outputs) do
      transaction
    end
    |> respond(conn)
  end

  defp respond_multiple(transactions, conn),
    do: render(conn, View.Transaction, :transactions, transactions: transactions)

  defp respond(%DB.Transaction{} = transaction, conn),
    do: render(conn, View.Transaction, :transaction, transaction: transaction)

  defp respond(nil, conn), do: handle_error(conn, :transaction_not_found)

  defp respond(%State.Transaction{} = transaction, conn),
    do: render(conn, View.Transaction, :transaction_encode, transaction: transaction)

  defp respond({:error, code}, conn) when is_atom(code), do: handle_error(conn, code)

  defp parse_params(%{"inputs" => inputs, "outputs" => outputs}) when is_list(inputs) and is_list(outputs) do
    if Enum.count(inputs) < 1 do
      {:error, :at_least_one_input_required}
    else
      %{"currency" => currency} = hd(inputs)
      currency = Base.decode16!(currency, case: :mixed)

      {:ok,
       {
         inputs
         |> Enum.map(&Map.delete(&1, "txbytes"))
         |> Enum.map(fn %{"currency" => currency} = input ->
           input =
             input
             |> Enum.into(
               %{},
               fn {k, v} ->
                 {String.to_existing_atom(k), v}
               end
             )

           currency = Base.decode16!(currency, case: :mixed)
           %{input | currency: currency}
         end),
         outputs
         |> Enum.map(fn %{} = output ->
           output = output |> Enum.into(%{}, fn {k, v} -> {String.to_existing_atom(k), v} end)
           output = %{output | owner: OMG.API.Crypto.decode_address!(output.owner)}
           Map.put(output, :currency, currency)
         end)
       }}
    end
  end

  def swagger_definitions do
    %{
      Transaction:
        swagger_schema do
          title("Transaction")

          properties do
            txid(:string, "Transaction id", required: true)
            blknum1(:integer, "Child chain block number of the first input utxo", required: true)
            txindex1(:integer, "Transaction index of the first input utxo", required: true)
            oindex1(:integer, "Output index of the first input utxo", required: true)
            blknum2(:integer, "Child chain block number of the second input utxo", required: true)
            txindex2(:integer, "Transaction index of the second input utxo", required: true)
            oindex2(:integer, "Output index of the second input utxo", required: true)
            cur12(:string, "Currency of the transaction", required: true)
            newowner1(:string, "Address of the owner of the first output utxo", required: true)
            amount1(:integer, "Amount of currency in the first output utxo", required: true)
            newowner2(:string, "Address of the owner of the second output utxo", required: true)
            amount2(:integer, "Amount of currency in the second output utxo", required: true)
            txblknum(:integer, "Number of block that the transaction is included in", required: true)
            txindex(:integer, "Transaction index", required: true)
            sig1(:string, "Signature of owner of the first input utxo", required: true)
            sig2(:string, "Signature of owner of the second input utxo", required: true)
            spender1(:string, "Address of owner of the first input utxo", required: true)
            spender2(:string, "Address of owner of the second input utxo", required: true)
            timestamp(:integer, "Timestamp of a block which the transaction was included in", required: true)
            eth_height(:integer, "Eth height where the block was submitted", required: true)
          end

          example(%{
            txid: "5DF13A6BF96DBCF6E66D8BABD6B55BD40D64D4320C3B115364C6588FC18C2A21",
            blknum1: 1000,
            txindex1: 2,
            oindex1: 0,
            blknum2: 2000,
            txindex2: 0,
            oindex2: 1,
            cur12: "0000000000000000000000000000000000000000",
            newowner1: "B3256026863EB6AE5B06FA396AB09069784EA8EA",
            amount1: 1,
            newowner2: "0000000000000000000000000000000000000000",
            amount2: 2,
            txblknum: 3000,
            txindex: 1,
            sig1:
              "F3050F1CC506480EFFBD78CB2FB21074AD3545564520F1E58F8F7BA1E37EF35450EB406A4173524CA0A6C4DE4D7EF7E814E161795EB8D852033E60F3539E61F71B",
            sig2:
              "0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
            spender1: "92EAD0DB732692FF887268DA965C311AC2C9005B",
            spender2: "92EAD0DB732692FF887268DA965C311AC2C9005B",
            timestamp: 1_540_365_586,
            eth_height: 6_573_395
          })
        end,
      Transactions:
        swagger_schema do
          title("Array of transactions")
          type(:array)
          items(Schema.ref(:Transaction))
        end,
      Output:
        swagger_schema do
          title("Output")

          properties do
            amount(:integer, "Amount of the currency. Currency is derived from inputs.", required: true)
            owner(:string, "Address of output's owner", required: true)
          end

          example(%{
            "amount" => 97,
            "owner" => "B3256026863EB6AE5B06FA396AB09069784EA8EA"
          })
        end,
      Outputs:
        swagger_schema do
          title("Array of outputs")
          type(:array)
          items(Schema.ref(:Output))
        end,
      PostTransaction:
        swagger_schema do
          title("Inputs and outputs to transaction")

          properties do
            inputs(Schema.ref(:Utxos), "Array of utxos to spend", required: true)
            outputs(Schema.ref(:Outputs), "Array of new owners and amounts", required: true)
          end
        end
    }
  end

  swagger_path :get_transaction do
    post("/transaction.get")
    summary("Gets a specific transaction")

    parameters do
      id(:body, :string, "Id of the transaction", required: true)
    end

    response(200, "OK", Schema.ref(:Transaction))
  end

  swagger_path :get_transactions do
    post("/transaction.all")
    summary("Gets a list of transactions")

    parameters do
      address(:body, :string, "Address of the sender or recipient", required: false)
      limit(:body, :integer, "Limits number of transactions. Default value is 200", required: false)
    end

    response(200, "OK", Schema.ref(:Transactions))
  end

  swagger_path :encode_transaction do
    post("/transaction.encode")
    summary("Produces hex-encoded transaction bytes for provided inputs and outputs")

    parameters do
      body(:body, Schema.ref(:PostTransaction), "The request body", required: true)
    end

    response(200, "OK")
  end
end

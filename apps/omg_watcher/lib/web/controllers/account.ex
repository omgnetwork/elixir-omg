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

defmodule OMG.Watcher.Web.Controller.Account do
  @moduledoc """
  Module provides operation related to plasma accounts.
  """

  use OMG.Watcher.Web, :controller
  use PhoenixSwagger

  alias OMG.API.Crypto
  alias OMG.Watcher.API
  alias OMG.Watcher.Web.View

  @doc """
  Gets plasma account balance
  """
  def get_balance(conn, params) do
    with {:ok, address} <- Map.fetch(params, "address"),
         {:ok, decoded_address} <- Crypto.decode_address(address) do
      balance = API.Account.get_balance(decoded_address)
      render(conn, View.Account, :balance, balance: balance)
    end
  end

  def get_utxos(conn, params) do
    with {:ok, address} <- Map.fetch(params, "address"),
         {:ok, decoded_address} <- Crypto.decode_address(address) do
      utxos = API.Account.get_utxos(decoded_address)

      render(conn, View.Utxo, :utxos, utxos: utxos)
    end
  end

  def swagger_definitions do
    %{
      CurrencyBalance:
        swagger_schema do
          title("Balance of the currency")

          properties do
            currency(:string, "Currency of the funds", required: true)
            amount(:integer, "Amount of the currency", required: true)
          end

          example(%{
            currency: String.duplicate("00", 20),
            amount: 10
          })
        end,
      Balance:
        swagger_schema do
          title("Array of currency balances")
          type(:array)
          items(Schema.ref(:CurrencyBalance))
        end,
      Utxo:
        swagger_schema do
          title("Utxo")

          properties do
            currency(:string, "Currency of the utxo", required: true)
            amount(:integer, "Amount of the currency", required: true)

            blknum(
              :integer,
              "Number of child chain block that contains transaction that created the utxo",
              required: true
            )

            txindex(:integer, "Number of transaction that created the utxo", required: true)
            oindex(:integer, "Output index in the transaction", required: true)
            txbytes(:string, "RLP encoded signed transaction that created the utxo", required: true)
          end

          example(%{
            currency: "0000000000000000000000000000000000000000",
            amount: 10,
            blknum: 1000,
            txindex: 1,
            oindex: 0,
            txbytes:
              "F8CF0101808080809400000000000000000000000000000000000000009459D87A1B128920C828C2648C9211F6626A9C82F28203E894000000000000000000000000000000000000000080B84196BE9F44CE42D5A20DC382AAB8C940BD25E8A9A7E50B9CE976ADEEB7EDE1348B1F7BBA11C5EB235CE732AD960EF7E71330C34C137A5D2C09FA9A2F8F680911CA1CB8410000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"
          })
        end,
      Utxos:
        swagger_schema do
          title("Array of utxos")
          type(:array)
          items(Schema.ref(:Utxo))
        end
    }
  end

  swagger_path :get_balance do
    post("/account.get_balance")
    summary("Responds with account balance for given account address")

    parameters do
      address(:path, :string, "Address of the funds owner", required: true)
    end

    response(200, "OK", Schema.ref(:Balance))
  end

  swagger_path :get_utxos do
    post("/account.get_utxos")
    summary("Gets all utxos belonging to the given address")

    parameters do
      address(:body, :string, "Address of utxo owner", required: true)
    end

    response(200, "OK", Schema.ref(:Utxos))
  end
end

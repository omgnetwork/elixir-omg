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
  alias OMG.Watcher.DB
  alias OMG.Watcher.Web.View

  @doc """
  Gets plasma account balance
  """
  def get_balance(conn, %{"address" => address}) do
    # TODO: handle input validation (separate task)
    {:ok, address_decode} = Crypto.decode_address(address)
    balance = DB.TxOutput.get_balance(address_decode)
    render(conn, View.Account, :balance, balance: balance)
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
        end
    }
  end

  swagger_path :get_balance do
    get("/account/{address}/balance")
    summary("Responds with account balance for given account address")

    parameters do
      address(:path, :string, "Address of funds owner", required: true)
    end

    response(200, "OK", Schema.ref(:Balance))
  end
end

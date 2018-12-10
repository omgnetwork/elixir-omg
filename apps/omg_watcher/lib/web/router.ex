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

defmodule OMG.Watcher.Web.Router do
  use OMG.Watcher.Web, :router

  pipeline :api do
    plug(:accepts, ["json"])
  end

  scope "/api/swagger" do
    forward("/", PhoenixSwagger.Plug.SwaggerUI, otp_app: :omg_watcher, swagger_file: "swagger.json")
  end

  scope "/", OMG.Watcher.Web do
    pipe_through([:api])

    post("/account.get_balance", Controller.Account, :get_balance)

    post("/transaction.all", Controller.Transaction, :get_transactions)
    post("/transaction.encode", Controller.Transaction, :transaction_encode)
    post("/transaction.get", Controller.Transaction, :get_transaction)

    post("/utxo.get", Controller.Utxo, :get_utxos)
    post("/utxo.get_exit_data", Controller.Utxo, :get_utxo_exit)
    post("/utxo.get_challenge_data", Controller.Challenge, :get_utxo_challenge)

    post("/status.get", Controller.Status, :get_status)

    match(:*, "/*path", Controller.Fallback, :not_found)
  end

  def swagger_info do
    %{
      info: %{
        version: "1.0",
        title: "OMG Watcher"
      }
    }
  end
end

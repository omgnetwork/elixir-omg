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

    get("/account/:address/balance", Controller.Account, :get_balance)

    get("/transaction/:id", Controller.Transaction, :get_transaction)
    post("/transaction", Controller.Transaction, :encode_transaction)

    get("/utxos", Controller.Utxo, :get_utxos)
    get("/utxo/:utxo_pos/exit_data", Controller.Utxo, :get_utxo_exit)
    get("/utxo/:utxo_pos/challenge_data", Controller.Challenge, :get_utxo_challenge)

    get("/status", Controller.Status, :get_status)

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

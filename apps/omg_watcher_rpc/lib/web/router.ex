# Copyright 2019 OmiseGO Pte Ltd
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

defmodule OMG.WatcherRPC.Web.Router do
  use OMG.WatcherRPC.Web, :router

  pipeline :api do
    plug(:accepts, ["json"])
  end

  scope "/", OMG.WatcherRPC.Web do
    pipe_through([:api])

    post("/account.get_balance", Controller.Account, :get_balance)
    post("/account.get_transactions", Controller.Transaction, :get_transactions)
    post("/account.get_utxos", Controller.Account, :get_utxos)
    post("/account.get_exitable_utxos", Controller.Account, :get_exitable_utxos)

    post("/in_flight_exit.get_data", Controller.InFlightExit, :get_in_flight_exit)
    post("/in_flight_exit.get_competitor", Controller.InFlightExit, :get_competitor)
    post("/in_flight_exit.prove_canonical", Controller.InFlightExit, :prove_canonical)
    post("/in_flight_exit.get_input_challenge_data", Controller.InFlightExit, :get_input_challenge_data)
    post("/in_flight_exit.get_output_challenge_data", Controller.InFlightExit, :get_output_challenge_data)

    post("/transaction.all", Controller.Transaction, :get_transactions)
    post("/transaction.get", Controller.Transaction, :get_transaction)
    post("/transaction.submit", Controller.Transaction, :submit)
    post("/transaction.submit_typed", Controller.Transaction, :submit_typed)
    post("/transaction.create", Controller.Transaction, :create)

    post("/utxo.get_exit_data", Controller.Utxo, :get_utxo_exit)
    post("/utxo.get_challenge_data", Controller.Challenge, :get_utxo_challenge)

    post("/status.get", Controller.Status, :get_status)
    post("/alarm.get", Controller.Alarm, :get_alarms)

    post("/fees.all", Controller.Fee, :get_all)

    # NOTE: This *has to* be the last route, catching all unhandled paths
    match(:*, "/*path", Controller.Fallback, Route.NotFound)
  end
end

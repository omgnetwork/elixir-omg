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

defmodule OmiseGOWatcherWeb.Router do
  use OmiseGOWatcherWeb, :router

  pipeline :api do
    plug(:accepts, ["json"])
  end

  scope "/", OmiseGOWatcherWeb do
    get("/account/utxo", Controller.Utxo, :available)
    get("/account/utxo/compose_exit", Controller.Utxo, :compose_utxo_exit)
    get("/status", Controller.Status, :get)
    get("/challenges", Controller.Challenge, :challenge)
  end

  scope "/transactions", OmiseGOWatcherWeb do
    get("/:id", Controller.Transaction, :get)
  end
end

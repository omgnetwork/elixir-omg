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

defmodule LoadTest.Scenario.FundAccount do
  @moduledoc """
  Funds an account with some ether from the faucet.
  Returns the new utxo in the session.
  """

  use Chaperon.Scenario

  alias Chaperon.Session
  alias LoadTest.Service.Faucet

  @eth <<0::160>>

  @spec run(Session.t()) :: Session.t()
  def run(session) do
    account = config(session, [:account])
    initial_funds = config(session, [:initial_funds])
    {:ok, utxo} = Faucet.fund_child_chain_account(account, initial_funds, @eth)

    Session.assign(session, utxo: utxo)
  end
end

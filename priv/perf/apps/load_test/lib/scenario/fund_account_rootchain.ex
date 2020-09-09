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

defmodule LoadTest.Scenario.FundAccountRootchain do
  @moduledoc """
  Funds an account with some ether from the faucet on the rootchain.

  ## configuration values
  - `account` the account to fund
  - `amount` the amount to fund (in wei)
  """

  use Chaperon.Scenario

  alias Chaperon.Session
  alias LoadTest.Service.Faucet

  @spec run(Session.t()) :: Session.t()
  def run(session) do
    account = config(session, [:account])
    amount = config(session, [:amount])
    {:ok, _} = Faucet.fund_root_chain_account(account, amount)
    session
  end
end

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

defmodule OMG.LoadTest.Utils.Generators do
  @moduledoc """
  Provides helper functions to generate bundles of various useful entities for performance tests
  """
  require Logger
  alias OMG.LoadTest.Utils.Account
  alias OMG.LoadTest.Utils.Faucet

  @type utxopos :: non_neg_integer
  @type entity :: {Account.t(), {utxopos, non_neg_integer}}

  @eth <<0::160>>

  @doc """
  Creates addresses with private keys and funds them with given `initial_funds_wei` on child chain.

  Options:
    - :initial_funds_wei - the amount of test ETH that will be granted to every generated user
  """
  @spec generate_users(non_neg_integer, [Keyword.t()]) :: {Account.t(), list(entity())}
  def generate_users(size, opts \\ []) do
    initial_funds = Application.fetch_env!(:omg_load_test, :initial_funds_wei)
    default = [initial_funds_wei: initial_funds]
    opts = Keyword.merge(default, opts)

    users =
      Enum.map(1..size, fn n ->
        Logger.debug("Funding user no. #{n}")
        generate_user(Keyword.fetch!(opts, :initial_funds_wei), @eth)
      end)

    {:ok, users}
  end

  defp generate_user(amount, token) do
    {:ok, user} = Account.new()
    {:ok, user_utxo} = Faucet.fund_child_chain_account(user, amount, token)
    {user, user_utxo}
  end
end

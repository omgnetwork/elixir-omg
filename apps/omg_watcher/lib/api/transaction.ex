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

defmodule OMG.Watcher.API.Transaction do
  @moduledoc """
  Module provides API for transactions
  """

  alias OMG.Watcher.DB

  @doc """
  Retrieves a specific transaction by id
  """
  @spec get(binary()) :: nil | %DB.Transaction{}
  def get(transaction_id) do
    DB.Transaction.get(transaction_id)
  end

  @doc """
  Retrieves a list of transactions that a given address is involved as input or output owner.
  Length of the list is limited by `limit` argument.
  If `nil` is given as `address` argument then a list of last 'limit' transactions is returned.
  """
  @spec get_transactions(nil | OMG.API.Crypto.address_t(), pos_integer()) :: list(%DB.Transaction{})
  def get_transactions(nil, limit), do: DB.Transaction.get_last(limit)

  def get_transactions(address, limit), do: DB.Transaction.get_by_address(address, limit)
end

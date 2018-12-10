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
  Module provides operations related to plasma accounts.
  """

  alias OMG.API.Crypto
  alias OMG.API.State
  alias OMG.Watcher.DB.Transaction

  @doc """
  Retrieves a specific transaction by id.
  """
  def get(transaction_id) do
    Transaction.get(transaction_id, true)
  end

  @doc """
  Retrieves a list of transactions
  """
  def get_transactions(address, limit) do
    if address == nil do
      Transaction.get_last(limit)
    else
      with {:ok, address_decode} <- Crypto.decode_address(address) do
        Transaction.get_by_address(address_decode, limit)
      end
    end
  end

  @doc """
  Produces hex-encoded transaction bytes for provided inputs and outputs.
  """
  def create_from_utxos(inputs, outputs) do
    State.Transaction.create_from_utxos(inputs, outputs)
  end
end

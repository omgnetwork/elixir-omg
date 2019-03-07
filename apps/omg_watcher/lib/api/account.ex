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

defmodule OMG.Watcher.API.Account do
  @moduledoc """
  Module provides operations related to plasma accounts.
  """

  alias OMG.Watcher.DB

  @doc """
  Returns a list of amounts of currencies that a given address owns
  """
  @spec get_balance(OMG.API.Crypto.address_t()) :: list(DB.TxOutput.balance())
  def get_balance(address) do
    DB.TxOutput.get_balance(address)
  end

  @doc """
  Returns all utxos owner by `address`
  """
  @spec get_utxos(OMG.API.Crypto.address_t()) :: list(%DB.TxOutput{})
  def get_utxos(address) do
    DB.TxOutput.get_utxos(address)
  end
end

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

  @doc """
  Gets all utxos belonging to the given address. Slow operation.
  """
  @spec get_exitable_utxos(OMG.Crypto.address_t()) :: list(OMG.State.Core.exitable_utxos())
  def get_exitable_utxos(address) do
    # OMG.DB.utxos() takes a while.
    {:ok, utxos} = OMG.DB.utxos()

    OMG.State.Core.standard_exitable_utxos(utxos, address)
  end
end

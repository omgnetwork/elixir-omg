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

defmodule OMG.WatcherInfo.API.Utxo do
  @moduledoc """
  Module provides operations related to plasma UTXOs.
  """

  alias OMG.Utils.Paginator
  alias OMG.WatcherInfo.DB

  @default_utxos_limit 100

  @doc """
  Retrieves a list of deposits, optionally filtered by `address`.
  Length of the list is limited by `limit`.
  Offset of the list is set by `page`.
  """
  @spec get_deposits(Keyword.t()) :: Paginator.t()
  def get_deposits(constraints) do
    paginator = Paginator.from_constraints(constraints, @default_utxos_limit)

    DB.TxOutput.get_deposits(paginator)
  end
end

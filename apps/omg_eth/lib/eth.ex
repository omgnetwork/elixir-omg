# Copyright 2019-2020 OMG Network Pte Ltd
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

defmodule OMG.Eth do
  @moduledoc """
  Library for common code of the adapter/port to contracts deployed on Ethereum.

  NOTE: The library code is not intended to be used outside of `OMG.Eth`: use `OMG.Eth.RootChain` and `OMG.Eth.Token` as main
  entrypoints to the contract-interaction functionality.

  NOTE: This wrapper is intended to be as thin as possible, only offering a consistent API to the Ethereum JSONRPC client and contracts.

  Handles other non-contract queries to the Ethereum client.

  Notes on encoding: All APIs of `OMG.Eth` and the submodules with contract APIs always use raw, decoded binaries
  for binaries - never use hex encoded binaries. Such binaries may be passed as is onto `ABI` related functions,
  however they must be encoded/decoded when entering/leaving the `Ethereumex` realm
  """

  require Logger
  import OMG.Eth.Encoding, only: [to_hex: 1, int_from_hex: 1]

  @type address :: <<_::160>>
  @type hash :: <<_::256>>
  @type send_transaction_opts() :: [send_transaction_option()]
  @type send_transaction_option() :: {:passphrase, binary()}

  def get_block_timestamp_by_number(height) do
    case Ethereumex.HttpClient.eth_get_block_by_number(to_hex(height), false) do
      {:ok, %{"timestamp" => timestamp_hex}} ->
        {:ok, int_from_hex(timestamp_hex)}

      other ->
        other
    end
  end
end

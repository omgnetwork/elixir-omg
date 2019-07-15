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

defmodule OMG.TypedDataHash.Config do
  @moduledoc """
  Separates computation of EIP-172 domain separator to allow precompute domain separator in TypedDataHash module's
  attribute, so it doesn't need to compute every time structure data is hashed.
  """

  alias OMG.Eth.Encoding
  alias OMG.TypedDataHash.Tools

  # Needed for test only to have value of address when `:contract_address` is not set
  @fallback_ari_network_address "0x44de0ec539b8c4a4b530c78620fe8320167f2f74"

  @doc """
  Returns EIP-712 domain based on values from configuration in a format `signTypedData` expects.
  """
  @spec domain_data_from_config() :: Tools.eip712_domain_t()
  def domain_data_from_config do
    contract_addr = Application.fetch_env!(:omg_eth, :contract_addr) || @fallback_ari_network_address

    Application.fetch_env!(:omg, :eip_712_domain)
    |> Map.new()
    |> Map.put_new(:verifyingContract, Encoding.from_hex(contract_addr))
    |> Map.update!(:salt, &Encoding.from_hex/1)
  end

  @doc """
  Computes default domain separator based on values from configuration.
  This value is taken to structured hash computation when no domain separator is passed.
  """
  @spec domain_separator_from_config() :: OMG.Crypto.hash_t()
  def domain_separator_from_config do
    domain_data_from_config()
    |> Tools.domain_separator()
  end
end

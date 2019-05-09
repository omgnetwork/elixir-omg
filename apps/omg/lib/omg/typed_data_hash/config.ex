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

defmodule OMG.TypedDataHash.Config do
  @moduledoc """
  Separates computation of EIP-172 domain separator to allow precompute domain separator in TypedDataHash module's
  attribute, so it doesn't need to compute every time structure data is hashed.
  """

  alias OMG.TypedDataHash.Tools

  # Address to be used for hashing without connection to Ethereum node.
  @fallback_ari_network_address "44de0ec539b8c4a4b530c78620fe8320167f2f74"

  @doc """
  Computes default domain separator based on values from configuration.
  This value is taken to structured hash computation when no domain separator is passed.
  """
  @spec compute_domain_separator_from_config() :: OMG.Crypto.hash_t()
  def compute_domain_separator_from_config do
    [
      name: name,
      version: version,
      salt: salt_hex
    ] = Application.fetch_env!(:omg, :eip_712_domain)

    contract_addr_hex = Application.fetch_env!(:omg_eth, :contract_addr) || @fallback_ari_network_address

    <<contract_addr::binary-size(20)>> = decode16!(contract_addr_hex)
    <<salt::binary-size(32)>> = decode16!(salt_hex)

    Tools.domain_separator(name, version, contract_addr, salt)
  end

  defp decode16!("0x" <> data), do: decode16!(data)
  defp decode16!(data), do: Base.decode16!(data, case: :mixed)
end

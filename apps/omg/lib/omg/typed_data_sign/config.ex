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

defmodule OMG.TypedDataSign.Config do
  @moduledoc """
  Separates computation of EIP-172 domain separator to allow precompute domain separator in TypedDataSign module's
  attribute, so it doesn't need to compute every time structure data is hashed.
  """

  alias OMG.Crypto

  @domain_encoded_type "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract,bytes32 salt)"
  @domain_type_hash Crypto.hash(@domain_encoded_type)

  @doc """
  Computes Domain Separator `hashStruct(eip712Domain)`,
  @see: http://eips.ethereum.org/EIPS/eip-712#definition-of-domainseparator
  """
  @spec domain_separator(binary(), binary(), Crypto.chain_id_t(), Crypto.address_t(), Crypto.hash_t()) ::
          Crypto.hash_t()
  def domain_separator(name, version, chain_id, verifying_contract, salt) do
    [
      @domain_type_hash,
      Crypto.hash(name),
      Crypto.hash(version),
      ABI.TypeEncoder.encode_raw([chain_id], [{:uint, 256}]),
      ABI.TypeEncoder.encode_raw([verifying_contract], [:address]),
      ABI.TypeEncoder.encode_raw([salt], [{:bytes, 32}])
    ]
    |> Enum.join()
    |> Crypto.hash()
  end

  @doc """
  Computes default domain separator based on values from configuration.
  This value is taken to structured hash computation when no domain separator is passed.
  """
  @spec compute_domain_separator_from_config() :: Crypto.hash_t()
  def compute_domain_separator_from_config do
    [
      name: name,
      version: version,
      chain_id: chain_id,
      verifying_contract: contract_addr_hex,
      salt: salt_hex
    ] = Application.fetch_env!(:omg, :eip712Domain)

    <<contract_addr::binary-size(20)>> = decode16!(contract_addr_hex)
    <<salt::binary-size(32)>> = decode16!(salt_hex)

    domain_separator(name, version, chain_id, contract_addr, salt)
  end

  defp decode16!("0x" <> data), do: decode16!(data)
  defp decode16!(data), do: Base.decode16!(data, case: :mixed)
end

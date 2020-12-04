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

defmodule OMG.Crypto do
  @moduledoc """
  Signs and validates signatures. Constructed signatures can be used directly
  in Ethereum with `ecrecover` call.

  For unsafe code, limited to `:test` and `:dev` environments and related to private key handling refer to:
  `OMG.DevCrypto` in `test/support`
  """
  alias ExPlasma.Crypto
  alias OMG.Signature

  @type sig_t() :: <<_::520>>
  @type pub_key_t() :: <<_::512>>
  @type priv_key_t() :: <<_::256>> | <<>>
  @type address_t() :: <<_::160>>
  @type hash_t() :: <<_::256>>
  @type domain_separator_t() :: <<_::256>> | nil

  @doc """
  Produces a KECCAK digest for the message.

  see https://hexdocs.pm/exth_crypto/ExthCrypto.Hash.html#kec/0

  ## Example

    iex> OMG.Crypto.hash("omg!")
    <<241, 85, 204, 147, 187, 239, 139, 133, 69, 248, 239, 233, 219, 51, 189, 54,
      171, 76, 106, 229, 69, 102, 203, 7, 21, 134, 230, 92, 23, 209, 187, 12>>
  """
  @spec hash(binary) :: hash_t()
  def hash(message), do: Crypto.keccak_hash(message)

  @doc """
  Recovers the address of the signer from a binary-encoded signature.
  """
  @spec recover_address(hash_t(), sig_t()) :: {:ok, address_t()} | {:error, :signature_corrupt | binary}
  def recover_address(<<digest::binary-size(32)>>, <<packed_signature::binary-size(65)>>) do
    case Signature.recover_public(digest, packed_signature) do
      {:ok, pub} ->
        generate_address(pub)

      {:error, "Recovery id invalid 0-3"} ->
        {:error, :signature_corrupt}

      other ->
        other
    end
  end

  @doc """
  Given public key, returns an address.
  """
  @spec generate_address(pub_key_t()) :: {:ok, address_t()}
  def generate_address(<<pub::binary-size(64)>>) do
    <<_::binary-size(12), address::binary-size(20)>> = hash(pub)
    {:ok, address}
  end
end

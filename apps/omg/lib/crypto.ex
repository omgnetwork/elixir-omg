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

defmodule OMG.Crypto do
  @moduledoc """
  Signs and validates signatures. Constructed signatures can be used directly
  in Ethereum with `ecrecover` call.

  For unsafe code, limited to `:test` and `:dev` environments and related to private key handling refer to:
  `OMG.DevCrypto` in `test/support`
  """

  @type sig_t() :: <<_::520>>
  @type pub_key_t() :: <<_::512>>
  @type priv_key_t() :: <<_::256>> | <<>>
  @type address_t() :: <<_::160>>
  @type hash_t() :: <<_::256>>

  @doc """
  Produces a cryptographic digest of a message.
  """
  def hash(message), do: message |> ExthCrypto.Hash.hash(ExthCrypto.Hash.kec())

  @doc """
  Verifies if private key corresponding to `address` was used to produce `signature` for
  this `msg` binary.
  """
  @spec verify(binary, binary, address_t()) :: {:ok, boolean}
  def verify(msg, signature, address) do
    {:ok, recovered_address} = msg |> hash() |> recover_address(signature)
    {:ok, address == recovered_address}
  end

  @doc """
  Recovers address of signer from binary-encoded signature.
  """
  @spec recover_address(<<_::256>>, sig_t()) :: {:ok, address_t()} | {:error, :signature_corrupt}
  def recover_address(<<digest::binary-size(32)>>, <<packed_signature::binary-size(65)>>) do
    with {:ok, pub} <- recover_public(digest, packed_signature) do
      generate_address(pub)
    end
  end

  @doc """
  Recovers public key of signer from binary-encoded signature.
  """
  @spec recover_public(<<_::256>>, <<_::520>>) :: {:ok, <<_::512>>} | {:error, :signature_corrupt}
  def recover_public(<<digest::binary-size(32)>>, <<packed_signature::binary-size(65)>>) do
    {v, r, s} = unpack_signature(packed_signature)

    with {:ok, _pub} = result <- Blockchain.Transaction.Signature.recover_public(digest, v, r, s) do
      result
    else
      {:error, "Recovery id invalid 0-3"} -> {:error, :signature_corrupt}
      other -> other
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

  @doc """
  Turns hex representation of an address to a binary
  """
  @spec decode_address(String.t() | binary) :: {:ok, address_t} | {:error, :bad_address_encoding}
  def decode_address("0x" <> address) when byte_size(address) == 40, do: Base.decode16(address, case: :lower)
  def decode_address(raw) when byte_size(raw) == 20, do: {:ok, raw}
  def decode_address(_), do: {:error, :bad_address_encoding}

  @doc """
  Returns hex representation of binary address
  """
  @spec encode_address(binary) :: {:ok, String.t()} | {:error, :invalid_address}
  def encode_address(address) when byte_size(address) == 20, do: {:ok, "0x" <> Base.encode16(address, case: :lower)}
  def encode_address(_), do: {:error, :invalid_address}

  # private

  # Unpack 65-bytes binary signature into {v,r,s} tuple.
  defp unpack_signature(<<r::integer-size(256), s::integer-size(256), v::integer-size(8)>>) do
    {v, r, s}
  end
end

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

defmodule OMG.DevCrypto do
  @moduledoc """
  Non-production crypto code like:
    - anything that touches private keys
  """

  alias OMG.Crypto
  alias OMG.SignatureHelper
  alias OMG.State.Transaction
  alias OMG.TypedDataHash

  @doc """
  Generates private key. Internally uses OpenSSL RAND_bytes. May throw if there is not enough entropy.
  """
  @spec generate_private_key() :: {:ok, Crypto.priv_key_t()}
  def generate_private_key(), do: {:ok, :crypto.strong_rand_bytes(32)}

  @doc """
  Given a private key, returns public key.
  """
  @spec generate_public_key(Crypto.priv_key_t()) :: {:ok, Crypto.pub_key_t()}
  def generate_public_key(<<priv::binary-size(32)>>) do
    {:ok, der_pub} = get_public_key(priv)
    {:ok, der_to_raw(der_pub)}
  end

  @doc """
    Signs transaction using private keys

    private keys are in the  binary form, e.g.:
    ```<<54, 43, 207, 67, 140, 160, 190, 135, 18, 162, 70, 120, 36, 245, 106, 165, 5, 101, 183,
      55, 11, 117, 126, 135, 49, 50, 12, 228, 173, 219, 183, 175>>```
  """
  @spec sign(Transaction.Protocol.t(), list(Crypto.priv_key_t())) :: Transaction.Signed.t()
  def sign(%{} = tx, private_keys) do
    sigs = Enum.map(private_keys, fn pk -> signature(tx, pk) end)
    %Transaction.Signed{raw_tx: tx, sigs: sigs}
  end

  @doc """
  Produces a stand-alone, 65 bytes long, signature for message hash.
  """
  @spec signature_digest(<<_::256>>, <<_::256>>) :: <<_::520>>
  def signature_digest(digest, priv) when is_binary(digest) and byte_size(digest) == 32 do
    {v, r, s} = SignatureHelper.sign_hash(digest, priv)
    pack_signature(v, r, s)
  end

  @doc """
  Produces a stand-alone, 65 bytes long, signature for a given transaction.
  """
  @spec signature(Transaction.Protocol.t(), Crypto.priv_key_t()) :: Crypto.sig_t()
  def signature(tx, priv), do: do_signature(tx, priv)

  defp do_signature(%{} = tx, priv) do
    tx
    |> TypedDataHash.hash_struct()
    |> signature_digest(priv)
  end

  # Pack a {v,r,s} signature as 65-bytes binary.
  defp pack_signature(v, r, s) do
    <<r::integer-size(256), s::integer-size(256), v::integer-size(8)>>
  end

  defp der_to_raw(<<4::integer-size(8), data::binary>>), do: data

  defp get_public_key(private_key) do
    case ExSecp256k1.create_public_key(private_key) do
      {:ok, public_key} -> {:ok, public_key}
      {:error, reason} -> {:error, to_string(reason)}
    end
  end
end

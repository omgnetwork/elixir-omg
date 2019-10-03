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

defmodule OMG.Signature do
  @moduledoc """
  Adapted from https://github.com/exthereum/blockchain.
  Defines helper functions for signing and getting the signature
  of a transaction, as defined in Appendix F of the Yellow Paper.

  For any of the following functions, if chain_id is specified,
  it's assumed that we're post-fork and we should follow the
  specification EIP-155 from:

  https://github.com/ethereum/EIPs/blob/master/EIPS/eip-155.md
  """
  @base_recovery_id 27
  @base_recovery_id_eip_155 35
  @signature_len 32

  @type keccak_hash :: binary()
  @type public_key :: <<_::512>>
  @type private_key :: <<_::256>>
  @type hash_v :: integer()
  @type hash_r :: integer()
  @type hash_s :: integer()
  @type signature_len :: unquote(@signature_len)

  @doc """
  Recovers a public key from a signed hash.

  This implements Eq.(208) of the Yellow Paper, adapted from https://stackoverflow.com/a/20000007

  """
  def recover_public(hash, <<r::integer-size(256), s::integer-size(256), v::integer-size(8)>>, chain_id \\ nil),
    do: recover_public(hash, v, r, s, chain_id)

  @spec recover_public(keccak_hash(), hash_v, hash_r, hash_s, integer() | nil) ::
          {:ok, public_key} | {:error, String.t()}
  def recover_public(hash, v, r, s, chain_id \\ nil) do
    signature =
      pad(:binary.encode_unsigned(r), @signature_len) <>
        pad(:binary.encode_unsigned(s), @signature_len)

    # Fork Ψ EIP-155
    recovery_id =
      if not is_nil(chain_id) and uses_chain_id?(v) do
        v - chain_id * 2 - @base_recovery_id_eip_155
      else
        v - @base_recovery_id
      end

    case :libsecp256k1.ecdsa_recover_compact(hash, signature, :uncompressed, recovery_id) do
      {:ok, <<_byte::8, public_key::binary()>>} -> {:ok, public_key}
      {:error, reason} -> {:error, to_string(reason)}
    end
  end

  @spec uses_chain_id?(hash_v) :: boolean()
  defp uses_chain_id?(v) do
    v >= @base_recovery_id_eip_155
  end

  @spec pad(binary(), signature_len()) :: binary()
  defp pad(binary, desired_length) do
    desired_bits = desired_length * 8

    case byte_size(binary) do
      0 ->
        <<0::size(desired_bits)>>

      x when x <= desired_length ->
        padding_bits = (desired_length - x) * 8
        <<0::size(padding_bits)>> <> binary

      _ ->
        raise "Binary too long for padding"
    end
  end
end

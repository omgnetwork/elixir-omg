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

  ## Example

    iex(1)> OMG.Signature.recover_public(<<2::256>>,
    ...(1)>     28,
    ...(1)>     38_938_543_279_057_362_855_969_661_240_129_897_219_713_373_336_787_331_739_561_340_553_100_525_404_231,
    ...(1)>     23_772_455_091_703_794_797_226_342_343_520_955_590_158_385_983_376_086_035_257_995_824_653_222_457_926
    ...(1)>     )
    {:ok,
     <<121, 190, 102, 126, 249, 220, 187, 172, 85, 160, 98, 149, 206, 135, 11, 7, 2, 155, 252, 219, 45, 206, 40,
       217, 89, 242, 129, 91, 22, 248, 23, 152, 72, 58, 218, 119, 38, 163, 196, 101, 93, 164, 251, 252, 14, 17,
       8, 168, 253, 23, 180, 72, 166, 133, 84, 25, 156, 71, 208, 143, 251, 16, 212, 184>>}
  """
  @spec recover_public(keccak_hash(), hash_v, hash_r, hash_s, integer() | nil) ::
          {:ok, public_key} | {:error, atom()}
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

    case ExSecp256k1.recover_compact(hash, signature, recovery_id) do
      {:ok, <<_byte::8, public_key::binary()>>} -> {:ok, public_key}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Recovers a public key from a signed hash.

  This implements Eq.(208) of the Yellow Paper, adapted from https://stackoverflow.com/a/20000007

  ## Example

    iex(1)> OMG.Signature.recover_public(<<2::256>>, <<168, 39, 110, 198, 11, 113, 141, 8, 168, 151, 22, 210, 198, 150, 24, 111, 23,
    ...(1)>         173, 42, 122, 59, 152, 143, 224, 214, 70, 96, 204, 31, 173, 154, 198, 97, 94,
    ...(1)>         203, 172, 169, 136, 182, 131, 11, 106, 54, 190, 96, 128, 227, 222, 248, 231,
    ...(1)>         75, 254, 141, 233, 113, 49, 74, 28, 189, 73, 249, 32, 89, 165, 27>>)
    {:ok,
      <<233, 102, 200, 175, 51, 251, 139, 85, 204, 181, 94, 133, 233, 88, 251, 156,
        123, 157, 146, 192, 53, 73, 125, 213, 245, 12, 143, 102, 54, 70, 126, 35, 34,
        167, 2, 255, 248, 68, 210, 117, 183, 156, 4, 185, 77, 27, 53, 239, 10, 57,
        140, 63, 81, 87, 133, 241, 241, 210, 250, 35, 76, 232, 2, 153>>}
  """
  def recover_public(hash, <<r::integer-size(256), s::integer-size(256), v::integer-size(8)>>, chain_id \\ nil) do
    recover_public(hash, v, r, s, chain_id)
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

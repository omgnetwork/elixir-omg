# Copyright 2019-2020 OmiseGO Pte Ltd
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

defmodule LoadTest.Utils.Encoding do
  @moduledoc """
  Utility module for converting between hex strings and other types.
  """

  @spec encode_data(String.t(), list()) :: binary
  defp encode_data(function_signature, data) do
    data = ABI.encode(function_signature, data)
    "0x" <> Base.encode16(data, case: :lower)
  end

  def to_binary(hex) do
    hex
    |> String.replace_prefix("0x", "")
    |> String.upcase()
    |> Base.decode16!()
  end

  @spec to_hex(binary | non_neg_integer) :: binary
  def to_hex(non_hex)

  def to_hex(raw) when is_binary(raw), do: "0x" <> Base.encode16(raw, case: :lower)
  def to_hex(int) when is_integer(int), do: "0x" <> Integer.to_string(int, 16)

  # because https://github.com/rrrene/credo/issues/583, we need to:
  # credo:disable-for-next-line Credo.Check.Consistency.SpaceAroundOperators
  @spec from_hex(<<_::16, _::_*8>>) :: binary
  def from_hex("0x" <> encoded), do: Base.decode16!(encoded, case: :lower)

  @spec encode_deposit(ExPlasma.Transaction.t()) :: %{data: binary()}
  def encode_deposit(transaction) do
    tx_bytes = ExPlasma.Transaction.encode(transaction)
    data = encode_data("deposit(bytes)", [tx_bytes])
    %{data: data}
  end

  @doc """
  Produces a stand-alone, 65 bytes long, signature for message hash.
  """
  @spec signature_digest(<<_::256>>, <<_::256>>) :: <<_::520>>
  def signature_digest(hash_digest, private_key_hash) do
    private_key_binary = to_binary(private_key_hash)

    {:ok, <<r::size(256), s::size(256)>>, recovery_id} =
      :libsecp256k1.ecdsa_sign_compact(
        hash_digest,
        private_key_binary,
        :default,
        <<>>
      )

    # EIP-155
    # See https://github.com/ethereum/EIPs/blob/master/EIPS/eip-155.md
    base_recovery_id = 27
    recovery_id = base_recovery_id + recovery_id

    <<r::integer-size(256), s::integer-size(256), recovery_id::integer-size(8)>>
  end
end

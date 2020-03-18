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

defmodule Itest.Transactions.Encoding do
  @moduledoc """
  Provides helper functions for encoding and decoding data.
  """
  @payment_tx_type 1

  alias Itest.Transactions.Deposit

  def get_data_for_rlp(%Deposit{inputs: inputs, outputs: outputs, metadata: metadata}),
    do: [@payment_tx_type, inputs, outputs, 0, metadata]

  def to_binary(hex) do
    hex
    |> String.replace_prefix("0x", "")
    |> String.upcase()
    |> Base.decode16!()
  end

  def to_hex(binary) when is_binary(binary),
    do: "0x" <> Base.encode16(binary, case: :lower)

  def to_hex(integer) when is_integer(integer),
    do: "0x" <> Integer.to_string(integer, 16)

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

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
defmodule OMG.SignatureHelper do
  @moduledoc false
  @doc """
  Returns a ECDSA signature (v,r,s) for a given hashed value.

  This implementes Eq.(207) of the Yellow Paper.

  """
  @base_recovery_id 27
  @base_recovery_id_eip_155 35
  @type keccak_hash :: binary()

  @type private_key :: <<_::256>>
  @type hash_v :: integer()
  @type hash_r :: integer()
  @type hash_s :: integer()
  @spec sign_hash(keccak_hash(), private_key, integer() | nil) ::
          {hash_v, hash_r, hash_s}
  def sign_hash(hash, private_key, chain_id \\ nil) do
    {:ok, <<r::size(256), s::size(256)>>, recovery_id} =
      :libsecp256k1.ecdsa_sign_compact(hash, private_key, :default, <<>>)

    # Fork Ψ EIP-155
    recovery_id =
      if chain_id do
        chain_id * 2 + @base_recovery_id_eip_155 + recovery_id
      else
        @base_recovery_id + recovery_id
      end

    {recovery_id, r, s}
  end
end

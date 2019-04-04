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

defmodule OMG.TypedDataSign do
  @moduledoc """
  Verifies typed structured data signatures (see: http://eips.ethereum.org/EIPS/eip-712)
  """

  alias OMG.Crypto
  alias OMG.Signature
  alias OMG.State.Transaction

  # TODO: compute this
  @domain_separator_v1 <<0::256>>

  @doc """
  Verifies if signature was created by private key corresponding to `address` and structured data
  used to sign was derived from `domain_separator` and `raw_tx`
  """
  @spec verify(Transaction.t(), binary(), Crypto.address_t(), Crypto.hash_t()) :: {:ok, boolean()}
  def verify(raw_tx, signature, address, domain_separator \\ @domain_separator_v1) do
    {:ok, false}
  end
end

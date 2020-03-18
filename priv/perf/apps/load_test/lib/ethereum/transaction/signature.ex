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

defmodule LoadTest.Ethereum.Transaction.Signature do
  @moduledoc """
  Defines helper functions for signing and getting the signature
  of a transaction, as defined in Appendix F of the Yellow Paper.

  For any of the following functions, if chain_id is specified,
  it's assumed that we're post-fork and we should follow the
  specification EIP-155 from:

  https://github.com/ethereum/EIPs/blob/master/EIPS/eip-155.md
  Extracted from: https://github.com/exthereum/blockchain
  """

  require Integer

  alias LoadTest.Ethereum.Hash
  alias LoadTest.Ethereum.Transaction

  @type private_key :: <<_::256>>

  @doc """
  Takes a given transaction and returns a version signed
  with the given private key. This is defined in Eq.(216) and
  Eq.(217) of the Yellow Paper.
  """
  @spec sign_transaction(Transaction.t(), private_key, integer() | nil) :: Transaction.t()
  def sign_transaction(trx, private_key, chain_id \\ nil) do
    {v, r, s} =
      trx
      |> Hash.transaction_hash(chain_id)
      |> Hash.sign_hash(private_key, chain_id)

    %{trx | v: v, r: r, s: s}
  end
end

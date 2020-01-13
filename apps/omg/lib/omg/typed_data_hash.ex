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

defmodule OMG.TypedDataHash do
  @moduledoc """
  Facilitates veryfing typed structured data (see: http://eips.ethereum.org/EIPS/eip-712) by producing a `hash_struct`
  for structured transaction data. These `struct_txhash`es are later used as digest to sign and recover signatures.
  """

  alias OMG.Crypto
  alias OMG.Output
  alias OMG.State.Transaction
  alias OMG.Utxo

  require Utxo

  @zero_address <<0::160>>

  # Precomputed hash of empty input for performance
  @empty_input_hash __MODULE__.Tools.hash_input(Utxo.position(0, 0, 0))

  # Precomputed hash of empty output for performance
  @empty_output_hash __MODULE__.Tools.hash_output(%Output{
                       owner: @zero_address,
                       currency: @zero_address,
                       amount: 0,
                       output_type: 0
                     })

  # Prefix and version byte motivated by http://eips.ethereum.org/EIPS/eip-191
  @eip_191_prefix <<0x19, 0x01>>

  @doc """
  Computes a hash of encoded transaction as defined in EIP-712
  """
  @spec hash_struct(Transaction.Payment.t(), Crypto.domain_separator_t()) :: Crypto.hash_t()
  def hash_struct(%Transaction.Payment{} = raw_tx, domain_separator \\ nil) do
    domain_separator = domain_separator || __MODULE__.Config.domain_separator_from_config()
    Crypto.hash(@eip_191_prefix <> domain_separator <> hash_transaction(raw_tx))
  end

  @spec hash_transaction(Transaction.Payment.t()) :: Crypto.hash_t()
  def hash_transaction(%Transaction.Payment{} = raw_tx) do
    __MODULE__.Tools.hash_transaction(
      raw_tx.tx_type,
      Transaction.get_inputs(raw_tx),
      Transaction.get_outputs(raw_tx),
      raw_tx.metadata,
      @empty_input_hash,
      @empty_output_hash
    )
  end
end

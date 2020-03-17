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

defmodule LoadTest.Utils.Ethereum.Hash do
  @moduledoc """
  Defines helper functions for signing and getting the signature
  of a transaction, as defined in Appendix F of the Yellow Paper.

  For any of the following functions, if chain_id is specified,
  it's assumed that we're post-fork and we should follow the
  specification EIP-155 from:

  https://github.com/ethereum/EIPs/blob/master/EIPS/eip-155.md
  Extracted from: https://github.com/exthereum/blockchain
  """

  alias LoadTest.Utils.Ethereum.BitHelper
  alias LoadTest.Utils.Ethereum.Transaction

  @base_recovery_id 27
  @base_recovery_id_eip_155 35
  @type private_key :: <<_::256>>
  @type hash_v :: integer()
  @type hash_r :: integer()
  @type hash_s :: integer()

  @doc """
  Returns a hash of a given transaction according to the
  formula defined in Eq.(214) and Eq.(215) of the Yellow Paper.

  Note: As per EIP-155 (https://github.com/ethereum/EIPs/blob/master/EIPS/eip-155.md),
        we will append the chain-id and nil elements to the serialized transaction.

  ## Examples

      iex> LoadTest.Utils.Ethereum.Hash.transaction_hash(%LoadTest.Utils.Ethereum.Transaction{nonce: 5, gas_price: 6, gas_limit: 7, to: <<>>, value: 5, init: <<1>>})
      <<127, 113, 209, 76, 19, 196, 2, 206, 19, 198, 240, 99, 184, 62, 8, 95, 9, 122, 135, 142, 51, 22, 61, 97, 70, 206, 206, 39, 121, 54, 83, 27>>

      iex> LoadTest.Utils.Ethereum.Hash.transaction_hash(%LoadTest.Utils.Ethereum.Transaction{nonce: 5, gas_price: 6, gas_limit: 7, to: <<1>>, value: 5, data: <<1>>})
      <<225, 195, 128, 181, 3, 211, 32, 231, 34, 10, 166, 198, 153, 71, 210, 118, 51, 117, 22, 242, 87, 212, 229, 37, 71, 226, 150, 160, 50, 203, 127, 180>>

      iex> LoadTest.Utils.Ethereum.Hash.transaction_hash(%LoadTest.Utils.Ethereum.Transaction{nonce: 5, gas_price: 6, gas_limit: 7, to: <<1>>, value: 5, data: <<1>>}, 1)
      <<132, 79, 28, 4, 212, 58, 235, 38, 66, 211, 167, 102, 36, 58, 229, 88, 238, 251, 153, 23, 121, 163, 212, 64, 83, 111, 200, 206, 54, 43, 112, 53>>
  """

  @spec transaction_hash(Transaction.t(), integer() | nil) :: BitHelper.keccak_hash()
  def transaction_hash(trx, chain_id \\ nil) do
    trx
    |> Transaction.serialize(false)
    # See EIP-155
    |> Kernel.++(if chain_id, do: [:binary.encode_unsigned(chain_id), <<>>, <<>>], else: [])
    |> ExRLP.encode()
    |> BitHelper.kec()
  end

  @doc """
  Returns a ECDSA signature (v,r,s) for a given hashed value.

  This implementes Eq.(207) of the Yellow Paper.

  ## Examples

    iex> LoadTest.Utils.Ethereum.Hash.sign_hash(<<2::256>>, <<1::256>>)
    {28,
     38938543279057362855969661240129897219713373336787331739561340553100525404231,
     23772455091703794797226342343520955590158385983376086035257995824653222457926}

    iex> LoadTest.Utils.Ethereum.Hash.sign_hash(<<5::256>>, <<1::256>>)
    {27,
     74927840775756275467012999236208995857356645681540064312847180029125478834483,
     56037731387691402801139111075060162264934372456622294904359821823785637523849}

    iex> data = Base.decode16!("ec098504a817c800825208943535353535353535353535353535353535353535880de0b6b3a764000080018080", case: :lower)
    iex> hash = LoadTest.Utils.Ethereum.BitHelper.kec(data)
    iex> private_key = Base.decode16!("4646464646464646464646464646464646464646464646464646464646464646", case: :lower)
    iex> LoadTest.Utils.Ethereum.Hash.sign_hash(hash, private_key, 1)
    { 37, 18515461264373351373200002665853028612451056578545711640558177340181847433846, 46948507304638947509940763649030358759909902576025900602547168820602576006531 }
  """
  @spec sign_hash(BitHelper.keccak_hash(), private_key, integer() | nil) ::
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

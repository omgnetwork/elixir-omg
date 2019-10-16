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

defmodule Eth.Blockchain.Transaction.Signature do
  @moduledoc """
  Defines helper functions for signing and getting the signature
  of a transaction, as defined in Appendix F of the Yellow Paper.

  For any of the following functions, if chain_id is specified,
  it's assumed that we're post-fork and we should follow the
  specification EIP-155 from:

  https://github.com/ethereum/EIPs/blob/master/EIPS/eip-155.md
  Extracted from: https://github.com/exthereum/blockchain
  """

  alias Eth.Blockchain.BitHelper
  alias Eth.Blockchain.Transaction
  alias Eth.Blockchain.Transaction.Hash

  @type private_key :: <<_::256>>
  @type hash_v :: integer()
  @type hash_r :: integer()
  @type hash_s :: integer()

  @base_recovery_id 27
  @base_recovery_id_eip_155 35

  @doc """
  Takes a given transaction and returns a version signed
  with the given private key. This is defined in Eq.(216) and
  Eq.(217) of the Yellow Paper.

  ## Examples

      iex> Eth.Blockchain.Transaction.Signature.sign_transaction(%Eth.Blockchain.Transaction{nonce: 5, gas_price: 6, gas_limit: 7, to: <<>>, value: 5, init: <<1>>}, <<1::256>>)
      %Eth.Blockchain.Transaction{data: <<>>, gas_limit: 7, gas_price: 6, init: <<1>>, nonce: 5, r: 97037709922803580267279977200525583527127616719646548867384185721164615918250, s: 31446571475787755537574189222065166628755695553801403547291726929250860527755, to: "", v: 27, value: 5}

      iex> Eth.Blockchain.Transaction.Signature.sign_transaction(%Eth.Blockchain.Transaction{nonce: 5, gas_price: 6, gas_limit: 7, to: <<>>, value: 5, init: <<1>>}, <<1::256>>, 1)
      %Eth.Blockchain.Transaction{data: <<>>, gas_limit: 7, gas_price: 6, init: <<1>>, nonce: 5, r: 25739987953128435966549144317523422635562973654702886626580606913510283002553, s: 41423569377768420285000144846773344478964141018753766296386430811329935846420, to: "", v: 38, value: 5}
  """
  @spec sign_transaction(Transaction.t(), private_key, integer() | nil) :: Transaction.t()
  def sign_transaction(trx, private_key, chain_id \\ nil) do
    {v, r, s} =
      trx
      |> Hash.transaction_hash(chain_id)
      |> sign_hash(private_key, chain_id)

    %{trx | v: v, r: r, s: s}
  end

  @doc """
  Returns a ECDSA signature (v,r,s) for a given hashed value.

  This implementes Eq.(207) of the Yellow Paper.

  ## Examples

    iex> Eth.Blockchain.Transaction.Signature.sign_hash(<<2::256>>, <<1::256>>)
    {28,
     38938543279057362855969661240129897219713373336787331739561340553100525404231,
     23772455091703794797226342343520955590158385983376086035257995824653222457926}

    iex> Eth.Blockchain.Transaction.Signature.sign_hash(<<5::256>>, <<1::256>>)
    {27,
     74927840775756275467012999236208995857356645681540064312847180029125478834483,
     56037731387691402801139111075060162264934372456622294904359821823785637523849}

    iex> data = Base.decode16!("ec098504a817c800825208943535353535353535353535353535353535353535880de0b6b3a764000080018080", case: :lower)
    iex> hash = Eth.Blockchain.BitHelper.kec(data)
    iex> private_key = Base.decode16!("4646464646464646464646464646464646464646464646464646464646464646", case: :lower)
    iex> Eth.Blockchain.Transaction.Signature.sign_hash(hash, private_key, 1)
    { 37, 18515461264373351373200002665853028612451056578545711640558177340181847433846, 46948507304638947509940763649030358759909902576025900602547168820602576006531 }
  """
  @spec sign_hash(BitHelper.keccak_hash(), private_key, integer() | nil) ::
          {hash_v, hash_r, hash_s}
  def sign_hash(hash, private_key, chain_id \\ nil) do
    private_key = maybe_hex(private_key)
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

  @spec maybe_hex(String.t() | nil) :: binary() | nil
  def maybe_hex(hex_data, type \\ :raw)
  def maybe_hex(nil, _), do: nil
  def maybe_hex(hex_data, :raw), do: load_raw_hex(hex_data)
  def maybe_hex(hex_data, :integer), do: load_hex(hex_data)

  @spec load_raw_hex(String.t()) :: binary()
  def load_raw_hex("0x" <> hex_data), do: load_raw_hex(hex_data)

  def load_raw_hex(hex_data) when Integer.is_odd(byte_size(hex_data)),
    do: load_raw_hex("0" <> hex_data)

  def load_raw_hex(hex_data) do
    Base.decode16!(hex_data, case: :mixed)
  end

  @spec load_hex(String.t()) :: non_neg_integer()
  def load_hex(hex_data), do: hex_data |> load_raw_hex |> :binary.decode_unsigned()
end

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

defmodule LoadTest.Ethereum.Transaction do
  alias LoadTest.Ethereum.BitHelper

  @moduledoc """
  This module encodes the transaction object, defined in Section 4.3
  of the Yellow Paper (http://gavwood.com/Paper.pdf). We are focused
  on implementing 𝛶, as defined in Eq.(1).
  Extracted from: https://github.com/exthereum/blockchain
  """
  defstruct nonce: 0,

            # Tn
            # Tp
            gas_price: 0,
            # Tg
            gas_limit: 0,
            # Tt
            to: <<>>,
            # Tv
            value: 0,
            # Tw
            v: nil,
            # Tr
            r: nil,
            # Ts
            s: nil,
            # Ti
            init: <<>>,
            # Td
            data: <<>>

  @type t :: %__MODULE__{
          nonce: integer(),
          gas_price: integer(),
          gas_limit: integer(),
          to: <<_::160>> | <<_::0>>,
          value: integer(),
          v: integer(),
          r: integer(),
          s: integer(),
          init: binary(),
          data: binary()
        }

  @doc """
  Encodes a transaction such that it can be RLP-encoded.
  This is defined at L_T Eq.(14) in the Yellow Paper.

  ## Examples

      iex> LoadTest.Ethereum.Transaction.serialize(%LoadTest.Ethereum.Transaction{nonce: 5, gas_price: 6, gas_limit: 7, to: <<1::160>>, value: 8, v: 27, r: 9, s: 10, data: "hi"})
      [<<5>>, <<6>>, <<7>>, <<1::160>>, <<8>>, "hi", <<27>>, <<9>>, <<10>>]

      iex> LoadTest.Ethereum.Transaction.serialize(%LoadTest.Ethereum.Transaction{nonce: 5, gas_price: 6, gas_limit: 7, to: <<>>, value: 8, v: 27, r: 9, s: 10, init: <<1, 2, 3>>})
      [<<5>>, <<6>>, <<7>>, <<>>, <<8>>, <<1, 2, 3>>, <<27>>, <<9>>, <<10>>]

      iex> LoadTest.Ethereum.Transaction.serialize(%LoadTest.Ethereum.Transaction{nonce: 5, gas_price: 6, gas_limit: 7, to: <<>>, value: 8, v: 27, r: 9, s: 10, init: <<1, 2, 3>>}, false)
      [<<5>>, <<6>>, <<7>>, <<>>, <<8>>, <<1, 2, 3>>]

      iex> LoadTest.Ethereum.Transaction.serialize(%LoadTest.Ethereum.Transaction{ data: "", gas_limit: 21000, gas_price: 20000000000, init: "", nonce: 9, r: 0, s: 0, to: "55555555555555555555", v: 1, value: 1000000000000000000 })
      ["\t", <<4, 168, 23, 200, 0>>, "R\b", "55555555555555555555", <<13, 224, 182, 179, 167, 100, 0, 0>>, "", <<1>>, "", ""]
  """
  @spec serialize(t) :: ExRLP.t()
  def serialize(trx, include_vrs \\ true) do
    base = [
      BitHelper.encode_unsigned(trx.nonce),
      BitHelper.encode_unsigned(trx.gas_price),
      BitHelper.encode_unsigned(trx.gas_limit),
      trx.to,
      BitHelper.encode_unsigned(trx.value),
      if(trx.to == <<>>, do: trx.init, else: trx.data)
    ]

    if include_vrs do
      base ++
        [
          BitHelper.encode_unsigned(trx.v),
          BitHelper.encode_unsigned(trx.r),
          BitHelper.encode_unsigned(trx.s)
        ]
    else
      base
    end
  end
end

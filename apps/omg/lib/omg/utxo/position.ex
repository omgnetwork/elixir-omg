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

defmodule OMG.Utxo.Position do
  @moduledoc """
  Representation of a UTXO position in the child chain, providing encoding/decoding to/from formats digestible in `Eth`
  and in the `OMG.DB`
  """

  @type t() :: {
          :utxo_position,
          # blknum
          non_neg_integer,
          # txindex
          non_neg_integer,
          # oindex
          non_neg_integer
        }

  @type db_t() :: {non_neg_integer, non_neg_integer, non_neg_integer}

  @spec decode!(integer()) :: t()
  def decode!(encoded) do
    {:ok, decoded} = decode(encoded)
    decoded
  end

  @spec decode(integer()) :: {:ok, t()} | {:error, :encoded_utxo_position_too_low}
  def decode(encoded) when is_integer(encoded) and encoded <= 0,
    do: {:error, :encoded_utxo_position_too_low}

  def decode(encoded) when is_integer(encoded) do
    %ExPlasma.Utxo{blknum: blknum, txindex: txindex, oindex: oindex} = ExPlasma.Utxo.new(encoded)
    {:ok, {:utxo_position, blknum, txindex, oindex}}
  end
end

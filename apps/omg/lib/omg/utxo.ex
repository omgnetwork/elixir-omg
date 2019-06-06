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

defmodule OMG.Utxo do
  @moduledoc """
  Manipulates a single unspent transaction output (UTXO) held be the child chain state.
  """

  alias OMG.Crypto
  alias OMG.State.Transaction

  defstruct [:owner, :currency, :amount, :creating_txhash]

  @type t() :: %__MODULE__{
          creating_txhash: Transaction.tx_hash(),
          owner: Crypto.address_t(),
          currency: Crypto.address_t(),
          amount: non_neg_integer()
        }

  @doc """
  Inserts a representation of an UTXO position, usable in guards. See Utxo.Position for handling of these entities
  """
  defmacro position(blknum, txindex, oindex) do
    quote do
      {:utxo_position, unquote(blknum), unquote(txindex), unquote(oindex)}
    end
  end

  defmacro is_position(blknum, txindex, oindex) do
    quote do
      is_integer(unquote(blknum)) and unquote(blknum) >= 0 and
        is_integer(unquote(txindex)) and unquote(txindex) >= 0 and
        is_integer(unquote(oindex)) and unquote(oindex) >= 0
    end
  end

  defmacrop is_nil_or_binary(binary) do
    quote do
      is_binary(unquote(binary)) or is_nil(unquote(binary))
    end
  end

  # NOTE: we have no migrations, so we handle data compatibility here (make_db_update/1 and from_db_kv/1), OMG-421
  def to_db_value(%__MODULE__{owner: owner, currency: currency, amount: amount, creating_txhash: creating_txhash})
      when is_binary(owner) and is_binary(currency) and is_integer(amount) and is_nil_or_binary(creating_txhash) do
    %{owner: owner, currency: currency, amount: amount, creating_txhash: creating_txhash}
  end

  def from_db_value(%{owner: owner, currency: currency, amount: amount, creating_txhash: creating_txhash})
      when is_binary(owner) and is_binary(currency) and is_integer(amount) and is_nil_or_binary(creating_txhash) do
    value = %{owner: owner, currency: currency, amount: amount, creating_txhash: creating_txhash}
    struct!(__MODULE__, value)
  end
end

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

  alias OMG.Output
  alias OMG.State.Transaction

  defstruct [:output, :creating_txhash]

  @type t() :: %__MODULE__{
          output: Output.Protocol.t(),
          creating_txhash: Transaction.tx_hash()
        }

  @doc """
  Inserts a representation of an UTXO position, usable in guards. See Utxo.Position for handling of these entities
  """
  defmacro position(blknum, txindex, oindex) do
    quote do
      {:utxo_position, unquote(blknum), unquote(txindex), unquote(oindex)}
    end
  end

  defguard is_position(blknum, txindex, oindex)
           when is_integer(blknum) and blknum >= 0 and
                  is_integer(txindex) and txindex >= 0 and
                  is_integer(oindex) and oindex >= 0

  @interval elem(OMG.Eth.RootChain.get_child_block_interval(), 1)
  @doc """
  Based on the contract parameters determines whether UTXO position provided was created by a deposit
  """
  defguard is_deposit(position)
           when is_tuple(position) and tuple_size(position) == 4 and
                  is_position(elem(position, 1), elem(position, 2), elem(position, 3)) and
                  rem(elem(position, 1), @interval) != 0

  defmacrop is_nil_or_binary(binary) do
    quote do
      is_binary(unquote(binary)) or is_nil(unquote(binary))
    end
  end

  # NOTE: we have no migrations, so we handle data compatibility here (make_db_update/1 and from_db_kv/1), OMG-421
  def to_db_value(%__MODULE__{output: output, creating_txhash: creating_txhash})
      when is_nil_or_binary(creating_txhash) do
    %{creating_txhash: creating_txhash}
    |> Map.put(:output, OMG.Output.Protocol.to_db_value(output))
  end

  def from_db_value(%{output: output, creating_txhash: creating_txhash})
      when is_nil_or_binary(creating_txhash) do
    value = %{
      output: OMG.Output.from_db_value(output),
      creating_txhash: creating_txhash
    }

    struct!(__MODULE__, value)
  end

  # Reading from old db format, only `OMG.Output.FungibleMoreVPToken`
  def from_db_value(%{owner: owner, currency: currency, amount: amount, creating_txhash: creating_txhash})
      when is_nil_or_binary(creating_txhash) do
    output = %{owner: owner, currency: currency, amount: amount}

    value = %{
      output: OMG.Output.FungibleMoreVPToken.from_db_value(output),
      creating_txhash: creating_txhash
    }

    struct!(__MODULE__, value)
  end
end

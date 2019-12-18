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

  alias OMG.State.Transaction

  defstruct [:output, :creating_txhash]

  @type t() :: %__MODULE__{
          output: OMG.Output.t(),
          creating_txhash: Transaction.tx_hash()
        }

  # NOTE: we have no migrations, so we handle data compatibility here (make_db_update/1 and from_db_kv/1), OMG-421
  def to_db_value(%__MODULE__{output: output, creating_txhash: creating_txhash})
      when is_binary(creating_txhash) or is_nil(creating_txhash) do
    %{output: OMG.Output.to_db_value(output), creating_txhash: creating_txhash}
  end

  def from_db_value(%{output: output, creating_txhash: creating_txhash})
      when is_binary(creating_txhash) or is_nil(creating_txhash) do
    value = %{
      output: OMG.Output.new(output),
      creating_txhash: creating_txhash
    }

    struct!(__MODULE__, value)
  end

  # Reading from old db format, only `OMG.Output`
  def from_db_value(%{owner: owner, currency: currency, amount: amount, creating_txhash: creating_txhash})
      when is_binary(creating_txhash) or is_nil(creating_txhash) do
    output = %{owner: owner, currency: currency, amount: amount}

    value = %{
      output: OMG.Output.new(output),
      creating_txhash: creating_txhash
    }

    struct!(__MODULE__, value)
  end
end

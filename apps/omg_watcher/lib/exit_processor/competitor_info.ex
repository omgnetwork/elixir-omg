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

defmodule OMG.Watcher.ExitProcessor.CompetitorInfo do
  @moduledoc """
  Represents the bulk of information about a competitor to an IFE.

  Internal stuff of `OMG.Watcher.ExitProcessor`
  """

  alias OMG.API.Crypto
  alias OMG.API.State.Transaction

  # mapped by tx_hash
  defstruct [
    :tx,
    # TODO: what if someone does challenges once more but with another input?
    :competing_input_index,
    :competing_input_signature
  ]

  @type t :: %__MODULE__{
          tx: Transaction.t(),
          competing_input_index: 1..4,
          competing_input_signature: Crypto.sig_t()
        }

  def make_db_update({_tx_hash, %__MODULE__{} = _competitor} = update) do
    {:put, :competitor_info, update}
  end

  def build_competitor(tx_bytes, competing_input_index, competing_input_signature) do
    with {:ok, raw_tx, []} <- Transaction.decode(tx_bytes) do
      {Transaction.hash(raw_tx),
       struct(__MODULE__,
         rx: raw_tx,
         competing_input_index: competing_input_index,
         competing_input_signature: competing_input_index
       )}
    end
  end
end

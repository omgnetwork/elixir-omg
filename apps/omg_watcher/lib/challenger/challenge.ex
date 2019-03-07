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

defmodule OMG.Watcher.Challenger.Challenge do
  @moduledoc """
  Represents a challenge
  """

  # NOTE: eutxoindex and cutxopos names were chosen for consistency with Solidity contract source code
  # eutoxoindex is index of exiting utxo in challenging transaction
  # cutxopos is position of challenging utxo
  defstruct [:exit_id, :txbytes, :input_index, :sig]

  @type t() :: %__MODULE__{
          exit_id: non_neg_integer(),
          txbytes: String.t(),
          input_index: non_neg_integer(),
          sig: String.t()
        }
end

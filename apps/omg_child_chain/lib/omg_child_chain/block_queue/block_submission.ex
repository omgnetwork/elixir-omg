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

defmodule OMG.ChildChain.BlockQueue.BlockSubmission do
  @moduledoc """
  Struct representing a block submission.
  """

  @type hash() :: <<_::256>>
  @type plasma_block_num() :: non_neg_integer()

  @type t() :: %__MODULE__{
          num: plasma_block_num(),
          hash: hash(),
          nonce: non_neg_integer(),
          gas_price: pos_integer()
        }
  defstruct [:num, :hash, :nonce, :gas_price]
end

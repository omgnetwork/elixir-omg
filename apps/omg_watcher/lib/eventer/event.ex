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

defmodule OMG.Watcher.Eventer.Event do
  alias OMG.API.Block
  alias OMG.API.State.Transaction

  @type t ::
          OMG.Watcher.Eventer.Event.AddressReceived.t()
          | OMG.Watcher.Eventer.Event.InvalidBlock.t()
          | OMG.Watcher.Eventer.Event.BlockWithholding.t()
          | OMG.Watcher.Eventer.Event.InvalidExit.t()

  defmodule AddressReceived do
    @moduledoc """
    Notifies about received funds by particular address
    """

    def name, do: "address_received"

    defstruct [:tx, :child_blknum, :child_block_hash, :submited_at_ethheight]

    @type t :: %__MODULE__{
            tx: Transaction.Recovered.t(),
            child_blknum: integer(),
            child_block_hash: Block.block_hash_t(),
            submited_at_ethheight: integer()
          }
  end

  defmodule AddressSpent do
    @moduledoc """
    Notifies about spent funds by particular address
    """

    def name, do: "address_spent"

    defstruct [:tx, :child_blknum, :child_block_hash, :submited_at_ethheight]

    @type t :: %__MODULE__{
            tx: Transaction.Recovered.t(),
            child_blknum: integer(),
            child_block_hash: Block.block_hash_t(),
            submited_at_ethheight: integer()
          }
  end

  defmodule InvalidBlock do
    @moduledoc """
    Notifies about invalid block
    """

    def name, do: "invalid_block"

    defstruct [:hash, :number, :error_type]

    @type t :: %__MODULE__{
            hash: Block.block_hash_t(),
            number: integer(),
            error_type: atom()
          }
  end

  defmodule BlockWithholding do
    @moduledoc """
    Notifies about block-withholding
    """

    def name, do: "block_withholding"

    defstruct [:blknum]

    @type t :: %__MODULE__{
            blknum: pos_integer()
          }
  end

  defmodule InvalidExit do
    @moduledoc """
    Notifies about invalid exit
    """

    def name, do: "invalid_exit"

    defstruct [:amount, :currency, :owner, :utxo_pos]

    @type t :: %__MODULE__{
            amount: pos_integer(),
            currency: binary(),
            owner: binary(),
            utxo_pos: pos_integer()
          }
  end
end

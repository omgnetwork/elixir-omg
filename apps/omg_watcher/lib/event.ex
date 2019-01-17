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

defmodule OMG.Watcher.Event do
  alias OMG.API.Block
  alias OMG.API.State.Transaction

  @type t ::
          OMG.Watcher.Event.AddressReceived.t()
          | OMG.Watcher.Event.InvalidBlock.t()
          | OMG.Watcher.Event.BlockWithholding.t()
          | OMG.Watcher.Event.InvalidExit.t()

  #  TODO The reason why events have name as String and byzantine events as atom is that
  #  Phoniex websockets requires topics as strings + currently we treat Strings and binaries in
  #  the same way in `OMG.Watcher.Web.Serializers.Response`
  defmodule AddressReceived do
    @moduledoc """
    Notifies about received funds by particular address
    """

    def name, do: "address_received"

    defstruct [:tx, :child_blknum, :child_txindex, :child_block_hash, :submited_at_ethheight]

    @type t :: %__MODULE__{
            tx: Transaction.Recovered.t(),
            child_blknum: integer(),
            child_txindex: integer(),
            child_block_hash: Block.block_hash_t(),
            submited_at_ethheight: integer()
          }
  end

  defmodule AddressSpent do
    @moduledoc """
    Notifies about spent funds by particular address
    """

    def name, do: "address_spent"

    defstruct [:tx, :child_blknum, :child_txindex, :child_block_hash, :submited_at_ethheight]

    @type t :: %__MODULE__{
            tx: Transaction.Recovered.t(),
            child_blknum: integer(),
            child_txindex: integer(),
            child_block_hash: Block.block_hash_t(),
            submited_at_ethheight: integer()
          }
  end

  defmodule InvalidBlock do
    @moduledoc """
    Notifies about invalid block
    """

    def name, do: :invalid_block

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

    def name, do: :block_withholding

    defstruct [:blknum]

    @type t :: %__MODULE__{
            blknum: pos_integer()
          }
  end

  defmodule InvalidExit do
    @moduledoc """
    Notifies about invalid exit
    """

    def name, do: :invalid_exit

    defstruct [:amount, :currency, :owner, :utxo_pos, :eth_height]

    @type t :: %__MODULE__{
            amount: pos_integer(),
            currency: binary(),
            owner: binary(),
            utxo_pos: pos_integer(),
            eth_height: pos_integer()
          }
  end

  defmodule UnchallengedExit do
    @moduledoc """
    Notifies about an invalid exit, that is dangerously approaching finalization, without being challenged

    It is a prompt to exit
    """

    def name, do: :unchallenged_exit

    defstruct [:amount, :currency, :owner, :utxo_pos, :eth_height]

    @type t :: %__MODULE__{
            amount: pos_integer(),
            currency: binary(),
            owner: binary(),
            utxo_pos: pos_integer(),
            eth_height: pos_integer()
          }
  end

  defmodule NonCanonicalIFE do
    @moduledoc """
    Notifies about an in-flight exit which has a competitor
    """

    def name, do: :non_canonical_ife

    defstruct [:txbytes]

    @type t :: %__MODULE__{
            txbytes: binary()
          }
  end

  # TODO: refactor and DRY this, it looks as if it could just be a field of the struct to pattern match out of a map
  def get_event_name(%InvalidBlock{}), do: InvalidBlock.name()
  def get_event_name(%BlockWithholding{}), do: BlockWithholding.name()
  def get_event_name(%InvalidExit{}), do: InvalidExit.name()
  def get_event_name(%UnchallengedExit{}), do: UnchallengedExit.name()
  def get_event_name(%NonCanonicalIFE{}), do: NonCanonicalIFE.name()
end

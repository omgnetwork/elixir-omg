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

defmodule OMG.Watcher.Event do
  @moduledoc """
  Definitions of structures representing various events delivered by the Watcher

  This module is agnostic of mode of delivery of events - both push and poll events go here
  """
  alias OMG.Block
  alias OMG.Crypto
  alias OMG.State.Transaction

  @type byzantine_t ::
          OMG.Watcher.Event.InvalidBlock.t()
          | OMG.Watcher.Event.BlockWithholding.t()
          | OMG.Watcher.Event.InvalidExit.t()
          | OMG.Watcher.Event.UnchallengedExit.t()
          | OMG.Watcher.Event.NonCanonicalIFE.t()
          | OMG.Watcher.Event.InvalidIFEChallenge.t()
          | OMG.Watcher.Event.PiggybackAvailable.t()
          | OMG.Watcher.Event.InvalidPiggyback.t()

  @type t ::
          OMG.Watcher.Event.AddressReceived.t()
          | OMG.Watcher.Event.ExitFinalized.t()
          | byzantine_t()

  @type module_t ::
          OMG.Watcher.Event.InvalidBlock
          | OMG.Watcher.Event.BlockWithholding
          | OMG.Watcher.Event.InvalidExit
          | OMG.Watcher.Event.UnchallengedExit
          | OMG.Watcher.Event.NonCanonicalIFE
          | OMG.Watcher.Event.InvalidIFEChallenge
          | OMG.Watcher.Event.PiggybackAvailable
          | OMG.Watcher.Event.InvalidPiggyback
          | OMG.Watcher.Event.AddressReceived
          | OMG.Watcher.Event.ExitFinalized
  #  TODO The reason why events have name as String and byzantine events as atom is that
  #  Phoniex websockets requires topics as strings + currently we treat Strings and binaries in
  #  the same way in `OMG.Watcher.Web.Serializers.Response`
  defmodule AddressReceived do
    @moduledoc """
    Notifies about received funds by particular address
    """

    defstruct [:tx, :child_blknum, :child_txindex, :child_block_hash, :submited_at_ethheight]

    @type t :: %__MODULE__{
            tx: Transaction.Recovered.t(),
            child_blknum: pos_integer(),
            child_txindex: non_neg_integer(),
            child_block_hash: Block.block_hash_t(),
            submited_at_ethheight: pos_integer()
          }
  end

  defmodule AddressSpent do
    @moduledoc """
    Notifies about spent funds by particular address
    """

    defstruct [:tx, :child_blknum, :child_txindex, :child_block_hash, :submited_at_ethheight]

    @type t :: %__MODULE__{
            tx: Transaction.Recovered.t(),
            child_blknum: pos_integer(),
            child_txindex: non_neg_integer(),
            child_block_hash: Block.block_hash_t(),
            submited_at_ethheight: pos_integer()
          }
  end

  defmodule ExitFinalized do
    @moduledoc """
    Notifies about finalized exit
    """

    defstruct [:currency, :amount, :child_blknum, :child_txindex, :child_oindex]

    @type t :: %__MODULE__{
            currency: Crypto.address_t(),
            amount: non_neg_integer(),
            child_blknum: non_neg_integer(),
            child_txindex: non_neg_integer(),
            child_oindex: non_neg_integer()
          }
  end

  defmodule InvalidBlock do
    @moduledoc """
    Notifies about invalid block
    """

    defstruct [:hash, :blknum, :error_type, name: :invalid_block]

    @type t :: %__MODULE__{
            hash: Block.block_hash_t(),
            blknum: integer(),
            error_type: atom(),
            name: atom()
          }
  end

  defmodule BlockWithholding do
    @moduledoc """
    Notifies about block-withholding
    """

    defstruct [:blknum, :hash, name: :block_withholding]

    @type t :: %__MODULE__{
            blknum: pos_integer(),
            hash: Block.block_hash_t(),
            name: atom()
          }
  end

  defmodule InvalidExit do
    @moduledoc """
    Notifies about invalid exit
    """

    defstruct [
      :amount,
      :currency,
      :owner,
      :utxo_pos,
      :root_chain_txhash,
      :eth_height,
      name: :invalid_exit
    ]

    @type t :: %__MODULE__{
            amount: pos_integer(),
            currency: binary(),
            owner: binary(),
            utxo_pos: pos_integer(),
            eth_height: pos_integer(),
            name: atom(),
            root_chain_txhash: Transaction.tx_hash() | nil
          }
  end

  defmodule UnchallengedExit do
    @moduledoc """
    Notifies about an invalid exit, that is dangerously approaching finalization, without being challenged

    It is a prompt to exit
    """

    defstruct [
      :amount,
      :currency,
      :owner,
      :utxo_pos,
      :root_chain_txhash,
      :eth_height,
      name: :unchallenged_exit
    ]

    @type t :: %__MODULE__{
            amount: pos_integer(),
            currency: binary(),
            owner: binary(),
            utxo_pos: pos_integer(),
            eth_height: pos_integer(),
            name: atom(),
            root_chain_txhash: Transaction.tx_hash() | nil
          }
  end

  defmodule NonCanonicalIFE do
    @moduledoc """
    Notifies about an in-flight exit which has a competitor
    """

    defstruct [:txbytes, name: :non_canonical_ife]

    @type t :: %__MODULE__{
            txbytes: binary(),
            name: atom()
          }
  end

  defmodule InvalidIFEChallenge do
    @moduledoc """
    Notifies about an in-flight exit which has a competitor
    """

    defstruct [:txbytes, name: :invalid_ife_challenge]

    @type t :: %__MODULE__{
            txbytes: binary(),
            name: atom()
          }
  end

  defmodule PiggybackAvailable do
    @moduledoc """
    Notifies about an available piggyback.
    It is only fired, when the transaction hasn't been seen included.
    """

    defstruct [:txbytes, :available_outputs, :available_inputs, name: :piggyback_available]

    @type available_output :: %{index: pos_integer(), address: binary()}

    @type t :: %__MODULE__{
            txbytes: binary(),
            available_outputs: list(available_output()),
            available_inputs: list(available_output()),
            name: atom()
          }
  end

  defmodule InvalidPiggyback do
    @moduledoc """
    Notifies about invalid piggyback. Piggyback is invalid if it is on input and that particular
    input was double-spend in other transaction (or other in-flight exit) or if it is on output
    that was spent on plasma chain.
    """

    defstruct [:txbytes, :inputs, :outputs, name: :invalid_piggyback]

    @type t :: %__MODULE__{
            txbytes: binary(),
            inputs: [non_neg_integer()],
            outputs: [non_neg_integer()],
            name: atom()
          }
  end
end

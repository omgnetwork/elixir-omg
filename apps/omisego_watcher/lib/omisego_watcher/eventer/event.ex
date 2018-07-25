defmodule OmiseGOWatcher.Eventer.Event do
  alias OmiseGO.API.Block
  alias OmiseGO.API.State.Transaction

  @type t ::
          OmiseGOWatcher.Eventer.Event.AddressReceived.t()
          | OmiseGOWatcher.Eventer.Event.InvalidBlock.t()
          | OmiseGOWatcher.Eventer.Event.BlockWithHolding.t()
          | OmiseGOWatcher.Eventer.Event.InvalidExit.t()

  defmodule AddressReceived do
    @moduledoc """
    Notifies about received funds by particular address
    """

    def name, do: "address_received"

    defstruct [:tx, :child_blknum, :child_block_hash, :submited_at_ethheight]

    @type t :: %AddressReceived{
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

    @type t :: %AddressSpent{
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

    defstruct [:eth_hash_block, :child_chain_hash_block, :transactions, :number, :error_type]

    @type t :: %InvalidBlock{
                 eth_hash_block: Block.block_hash_t(),
                 child_chain_hash_block: Block.block_hash_t(),
                 transactions: list(map()),
                 number: integer(),
                 error_type: atom(),
               }
  end

  defmodule BlockWithHolding do
    @moduledoc """
    Notifies about block-withholding
    """

    def name, do: "block_withholding"

    defstruct [:blknum]

    @type t :: %BlockWithHolding{
            blknum: pos_integer
          }
  end

  defmodule InvalidExit do
    @moduledoc """
    Notifies about invalid exit
    """

    def name, do: "invalid_exit"

    defstruct []

    @type t :: %InvalidExit{}
  end
end

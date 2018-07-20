defmodule OmiseGOWatcher.Eventer.Event do
  alias OmiseGO.API.Block
  alias OmiseGO.API.State.Transaction

  @type t :: OmiseGOWatcher.Eventer.Event.AddressReceived.t()

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
end

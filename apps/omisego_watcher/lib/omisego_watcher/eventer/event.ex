defmodule OmiseGOWatcher.Eventer.Event do
  @type t :: OmiseGOWatcher.Eventer.Event.AddressReceived.t() |
             OmiseGOWatcher.Eventer.Event.InvalidBlock.t() |
             OmiseGOWatcher.Eventer.Event.BlockWithHolding.t() |
             OmiseGOWatcher.Eventer.Event.InvalidExit.t()

  defmodule AddressReceived do
    @moduledoc """
    Notifies about received funds by particular address
    """

    def name, do: "address_received"

    defstruct [:tx, :child_blknum, :child_block_hash, :submited_at_ethheight]

    @type t :: %AddressReceived{
                 tx: any()
               }
  end

  defmodule InvalidBlock do
    @moduledoc """
    Notifies about invalid block
    """

    def name, do: "invalid_block"

    defstruct []

    @type t :: %InvalidBlock{}
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

defmodule OmiseGOWatcher.Eventer.Event do
  @type t :: OmiseGOWatcher.Eventer.Event.AddressReceived.t()

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
end

defmodule OmiseGOWatcher.Eventer.Event do
  @type t :: OmiseGOWatcher.Eventer.Event.AddressReceived.t()

  defmodule AddressReceived do
    @moduledoc """
    Notifies about received funds by particular address
    """

    def name, do: "address_received"

    defstruct [:tx]

    @type t :: %AddressReceived{
            tx: any()
          }
  end
end

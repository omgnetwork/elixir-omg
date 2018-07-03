defmodule OmiseGOWatcher.Eventer.Event do
  @type t :: OmiseGOWatcher.Eventer.Event.Address_Received.t()

  defmodule Address_Received do
    @moduledoc """
    Notifies about received funds by particular address
    """

    defstruct [:tx]

    @type t :: %Address_Received{
            tx: any()
          }
  end
end

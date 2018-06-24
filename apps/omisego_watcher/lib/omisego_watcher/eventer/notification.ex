defmodule OmiseGOWatcher.Eventer.Notification do
  @type t ::
          OmiseGOWatcher.Eventer.Notification.Received.t()
          | OmiseGOWatcher.Eventer.Notification.Spent.t()
          | OmiseGOWatcher.Eventer.Notification.BlockFinalized.t()

  defmodule Received do
    @moduledoc """
    Notifies about received transaction
    """

    defstruct [:tx]

    @type t :: %Received{
            tx: any()
          }
  end

  defmodule Spent do
    @moduledoc """
    Notifies about spent transaction
    """

    defstruct [:tx]

    @type t :: %Spent{
            tx: any()
          }
  end

  defmodule BlockFinalized do
    @moduledoc """
    Notifies about block considered final
    """

    defstruct [:number, :hash]

    @type t :: %BlockFinalized{
            number: pos_integer(),
            hash: binary()
          }
  end
end

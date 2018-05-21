defmodule OmiseGO.API.Notification do
  @type t :: OmiseGO.API.Notification.Received.t()
  | OmiseGO.API.Notification.Spent.t()
  | OmiseGO.API.Notification.BlockFinalized.t()

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

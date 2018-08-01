defmodule OmiseGO.API.RootChainCoordinator.Service do
  @moduledoc """
  Represents a service that is coordinated by root chain coordinator.
  """

  defstruct synced_height: nil, pid: nil

  @type t() :: %__MODULE__{
          synced_height: pos_integer(),
          pid: pid()
        }
end

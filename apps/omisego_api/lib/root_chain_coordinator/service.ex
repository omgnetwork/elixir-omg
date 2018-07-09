defmodule OmiseGO.API.RootChainCoordinator.Service do
  @moduledoc """
  Represents a service that is coordinated by root chain coordinator.
  """

  defstruct otp_handle: nil, synced_height: nil, pid: nil

  @type t() :: %__MODULE__{
          otp_handle: {pid(), atom()},
          synced_height: pos_integer(),
          pid: pid()
        }
end

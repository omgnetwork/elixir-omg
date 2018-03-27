defmodule OmiseGO.API.Application do
  @moduledoc false

  use Application
  import Supervisor.Spec

  def start(_type, _args) do
    children = [
      supervisor(Phoenix.PubSub.PG2, [:eventer, []]),
      {OmiseGO.API.State, []},
      {OmiseGO.API.BlockQueue.Server, []},
    ]
    opts = [strategy: :one_for_one]
    Supervisor.start_link(children, opts)
  end
end

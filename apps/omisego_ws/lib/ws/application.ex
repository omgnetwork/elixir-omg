defmodule OmiseGO.WS.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [OmiseGO.WS.Server]
    opts = [strategy: :one_for_one, name: OmiseGO.WS.Supervisor]
    Supervisor.start_link(children, opts)
  end
end

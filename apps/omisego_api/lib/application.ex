defmodule HanabiEngine.Application do
  @moduledoc false

  use Application
  import Supervisor.Spec

  def start(_type, _args) do
    children = [
      supervisor(Phoenix.PubSub.PG2, [:eventer, [ ]]),
    ]
    opts = [strategy: :one_for_one]
    Supervisor.start_link(children, opts)
  end
end

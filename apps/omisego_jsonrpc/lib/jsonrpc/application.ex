defmodule OmiseGO.JSONRPC.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    omisego_port = Application.get_env(:omisego_jsonrpc, :omisego_api_rpc_port)

    children = [
      JSONRPC2.Servers.HTTP.child_spec(:http, OmiseGO.JSONRPC.Server.Handler, port: omisego_port)
    ]

    opts = [strategy: :one_for_one, name: OmiseGO.JSONRPC.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
